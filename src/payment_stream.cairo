#[starknet::contract]
mod PaymentStream {
    use starknet::{get_block_timestamp, get_caller_address, contract_address_const, storage::Map};
    use core::traits::Into;
    use core::num::traits::Zero;
    use starknet::ContractAddress;
    use crate::base::types::{Stream, StreamStatus};
    use fundable::interfaces::IPaymentStream::IPaymentStream;
    use crate::base::errors::Errors::{
        ZERO_AMOUNT, INVALID_TOKEN, UNEXISTING_STREAM, WRONG_RECIPIENT, WRONG_SENDER,
        INVALID_RECIPIENT, END_BEFORE_START,
    };
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: Src5Event);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    const PROTOCOL_OWNER_ROLE: felt252 = selector!("PROTOCOL_OWNER");
    const STREAM_ADMIN_ROLE: felt252 = selector!("STREAM_ADMIN");

    #[storage]
    struct Storage {
        next_stream_id: u256,
        streams: Map<u256, Stream>,
        protocol_fee_percentage: u16,
        fee_collector: ContractAddress,
        protocol_owner: ContractAddress,
        accumulated_fees: Map<ContractAddress, u256>,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        StreamCreated: StreamCreated,
        StreamWithdrawn: StreamWithdrawn,
        StreamCanceled: StreamCanceled,
        StreamPaused: StreamPaused,
        StreamRestarted: StreamRestarted,
        StreamVoided: StreamVoided,
        FeeCollected: FeeCollected,
        WithdrawalSuccessful: WithdrawalSuccessful,
        #[flat]
        Src5Event: SRC5Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct FeeCollected {
        #[key]
        stream_id: u256,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct WithdrawalSuccessful {
        #[key]
        stream_id: u256,
        token: ContractAddress,
        amount: u256,
        recipient: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct StreamCreated {
        #[key]
        stream_id: u256,
        sender: ContractAddress,
        recipient: ContractAddress,
        total_amount: u256,
        token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct StreamWithdrawn {
        #[key]
        stream_id: u256,
        recipient: ContractAddress,
        amount: u256,
        protocol_fee: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct StreamCanceled {
        #[key]
        stream_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct StreamPaused {
        #[key]
        stream_id: u256,
        pause_time: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct StreamRestarted {
        #[key]
        stream_id: u256,
        rate_per_second: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct StreamVoided {
        #[key]
        stream_id: u256
    }

    #[constructor]
    fn constructor(ref self: ContractState, protocol_owner: ContractAddress) {
        self.accesscontrol.initializer();
        self.protocol_owner.write(protocol_owner);
        self.accesscontrol._grant_role(PROTOCOL_OWNER_ROLE, protocol_owner);
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_stream_exists(self: @ContractState, stream_id: u256) {
            let stream = self.streams.read(stream_id);
            assert(!stream.sender.is_zero(), UNEXISTING_STREAM);
        }

        fn assert_is_recipient(self: @ContractState, stream_id: u256) {
            let stream = self.streams.read(stream_id);
            assert(get_caller_address() == stream.recipient, WRONG_RECIPIENT);
        }

        fn assert_is_sender(self: @ContractState, stream_id: u256) {
            let stream = self.streams.read(stream_id);
            assert(get_caller_address() == stream.sender, WRONG_SENDER);
        }

        fn calculate_stream_rate(total_amount: u256, duration: u64) -> u256 {
            if duration == 0 {
                return 0;
            }
            total_amount / duration.into()
        }

        /// @notice points basis: 100pbs = 1%
        fn calculate_protocol_fee(self: @ContractState, total_amount: u256) -> u256 {
            let protocol_fee_percentage = self.protocol_fee_percentage.read();
            let fee = (total_amount * protocol_fee_percentage.into()) / 10000;
            fee
        }

        fn collect_protocol_fee(
            self: @ContractState, sender: ContractAddress, token: ContractAddress, amount: u256
        ) {
            let fee_collector: ContractAddress = self.fee_collector.read();
            assert(fee_collector.is_non_zero(), 'Fee collector is zero addr');
            ERC20ABIDispatcher { contract_address: token }
                .transfer_from(sender, fee_collector, amount);
        }
    }

    #[abi(embed_v0)]
    impl PaymentStreamImpl of IPaymentStream<ContractState> {
        fn create_stream(
            ref self: ContractState,
            recipient: ContractAddress,
            total_amount: u256,
            start_time: u64,
            end_time: u64,
            cancelable: bool,
            token: ContractAddress,
        ) -> u256 {
            // Validate inputs
            assert(!recipient.is_zero(), 'Invalid recipient');
            assert(total_amount > 0, 'Amount must be > 0');
            assert(end_time > start_time, 'End time before start time');
            assert(!token.is_zero(), 'Invalid token address');

            let caller = get_caller_address();
            let stream_id = self.next_stream_id.read();
            self.next_stream_id.write(stream_id + 1);

            // Create new stream
            let stream = Stream {
                owner: caller,
                sender: get_caller_address(),
                recipient,
                token,
                total_amount,
                start_time,
                end_time,
                withdrawn_amount: 0,
                cancelable,
                status: StreamStatus::Active,
                rate_per_second: 0,
                last_update_time: 0,
            };

            self.accesscontrol._grant_role(STREAM_ADMIN_ROLE, stream.owner);
            self.streams.write(stream_id, stream);

            self
                .emit(
                    Event::StreamCreated(
                        StreamCreated {
                            stream_id, sender: get_caller_address(), recipient, total_amount, token,
                        },
                    ),
                );

            stream_id
        }


        fn withdraw(
            ref self: ContractState, stream_id: u256, amount: u256, to: ContractAddress,
        ) -> (u128, u128) {
            // Return dummy values for (withdrawn_amount, protocol_fee_amount)
            // let stream = self.streams.read(stream_id);
            // let stream_token_balance = stream.
            // self.accesscontrol.assert_only_role(STREAM_ADMIN_ROLE);

            // assert(amount > 0, 'Invalid amount');
            // assert(to.is_non_zero(), 'Zero address');

            // let token_address = stream.token;

            (0_u128, 0_u128)
        }

        fn withdraw_max(
            ref self: ContractState, stream_id: u256, to: ContractAddress,
        ) -> (u128, u128) {
            // Return dummy values for (withdrawn_amount, protocol_fee_amount)
            (0_u128, 0_u128)
        }

        fn withdraw_protocol_fee(
            ref self: ContractState,
            recipient: ContractAddress,
            amount: u256,
            token: ContractAddress
        ) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);
            assert(amount > 0, 'amount is 0');
            assert(recipient.is_non_zero(), 'Zero recipient address');

            let fee_collector = self.fee_collector.read();
            let _success = ERC20ABIDispatcher { contract_address: token }
                .transfer_from(fee_collector, recipient, amount);
            assert(_success, 'token withdrawal fail...');

            let accumulated_fees = self.accumulated_fees.read(token);
            self.accumulated_fees.write(token, accumulated_fees - amount);
        }

        fn withdraw_max_protocol_fee(
            ref self: ContractState, recipient: ContractAddress, token: ContractAddress
        ) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);
            assert(recipient.is_non_zero(), 'Zero recipient address');

            let fee_collector = self.fee_collector.read();

            let max_amount = ERC20ABIDispatcher { contract_address: token }
                .balance_of(fee_collector);

            let _success = ERC20ABIDispatcher { contract_address: token }
                .transfer_from(fee_collector, recipient, max_amount);
            assert(_success, 'token withdrawal fail...');

            let accumulated_fees = self.accumulated_fees.read(token);
            self.accumulated_fees.write(token, accumulated_fees - max_amount);
        }

        fn update_percentage_protocol_fee(ref self: ContractState, new_percentage: u16) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);

            let protocol_fee_percentage = self.protocol_fee_percentage.read();
            assert(
                new_percentage > 0 && new_percentage != protocol_fee_percentage,
                'invalid fee percentage'
            );

            self.protocol_fee_percentage.write(new_percentage);
        }

        fn update_fee_collector(ref self: ContractState, new_fee_collector: ContractAddress) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);

            let fee_collector = self.fee_collector.read();
            assert(new_fee_collector.is_non_zero(), 'Zero address');
            assert(new_fee_collector != fee_collector, 'same collector address');

            self.fee_collector.write(new_fee_collector);
        }

        fn update_protocol_owner(ref self: ContractState, new_protocol_owner: ContractAddress) {
            let current_owner = self.protocol_owner.read();
            assert(new_protocol_owner.is_non_zero(), 'Invalid address');
            assert(new_protocol_owner != current_owner, 'current owner == new_owner');
    
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);
    
            self.protocol_owner.write(new_protocol_owner);
    
            self.accesscontrol.revoke_role(PROTOCOL_OWNER_ROLE, current_owner);
            self.accesscontrol._grant_role(PROTOCOL_OWNER_ROLE, new_protocol_owner);
        }

        fn get_fee_collector(self: @ContractState) -> ContractAddress {
            self.fee_collector.read()
        }

        fn cancel(ref self: ContractState, stream_id: u256) { // Empty implementation
        // todo!()
        }

        fn pause(ref self: ContractState, stream_id: u256) { // Empty implementation
        // todo!()
        }

        fn restart(
            ref self: ContractState, stream_id: u256, rate_per_second: u256,
        ) { // Empty implementation
        //  todo!()
        }

        fn void(ref self: ContractState, stream_id: u256) { // Empty implementation
        //  todo!()
        }

        fn get_stream(self: @ContractState, stream_id: u256) -> Stream {
            // Return dummy stream
            Stream {
                owner: starknet::contract_address_const::<0>(),
                sender: starknet::contract_address_const::<0>(),
                recipient: starknet::contract_address_const::<0>(),
                token: starknet::contract_address_const::<0>(),
                total_amount: 0_u256,
                start_time: 0_u64,
                end_time: 0_u64,
                withdrawn_amount: 0_u256,
                cancelable: false,
                status: StreamStatus::Active,
                rate_per_second: 0,
                last_update_time: 0,
            }
        }

        fn get_withdrawable_amount(self: @ContractState, stream_id: u256) -> u256 {
            // Return dummy amount
            0_u256
        }

        fn is_stream_active(self: @ContractState, stream_id: u256) -> bool {
            // Return dummy status
            false
        }

        fn get_depletion_time(self: @ContractState, stream_id: u256) -> u64 {
            // Return dummy timestamp
            0_u64
        }

        fn get_total_debt(self: @ContractState, stream_id: u256) -> u256 {
            // Return dummy amount
            0_u256
        }

        fn get_uncovered_debt(self: @ContractState, stream_id: u256) -> u256 {
            // Return dummy amount
            0_u256
        }

        fn get_covered_debt(self: @ContractState, stream_id: u256) -> u256 {
            // Return dummy amount
            0_u256
        }

        fn get_refundable_amount(self: @ContractState, stream_id: u256) -> u256 {
            // Return dummy amount
            0_u256
        }
    }

}
