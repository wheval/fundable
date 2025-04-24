#[starknet::contract]
pub mod PaymentStream {
    use core::num::traits::{Pow, Zero};
    use core::traits::Into;
    use fp::UFixedPoint123x128;
    use fundable::interfaces::IPaymentStream::IPaymentStream;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{
        IERC20Dispatcher, IERC20DispatcherTrait, IERC20MetadataDispatcher,
        IERC20MetadataDispatcherTrait,
    };
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use crate::base::errors::Errors::{
        DECIMALS_TOO_HIGH, INSUFFICIENT_ALLOWANCE, INSUFFICIENT_AMOUNT, INVALID_RECIPIENT,
        INVALID_TOKEN, NON_TRANSFERABLE_STREAM, TOO_SHORT_DURATION, UNEXISTING_STREAM,
        WRONG_RECIPIENT, WRONG_RECIPIENT_OR_DELEGATE, WRONG_SENDER, ZERO_AMOUNT,
    };
    use crate::base::types::{ProtocolMetrics, Stream, StreamMetrics, StreamStatus};

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: Src5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    const PROTOCOL_OWNER_ROLE: felt252 = selector!("PROTOCOL_OWNER");
    const STREAM_ADMIN_ROLE: felt252 = selector!("STREAM_ADMIN");

    const MAX_FEE: u256 = 5000;


    #[storage]
    struct Storage {
        next_stream_id: u256,
        streams: Map<u256, Stream>,
        protocol_fee_percentage: u16,
        fee_collector: ContractAddress,
        protocol_owner: ContractAddress,
        accumulated_fees: Map<ContractAddress, u256>,
        protocol_fees: Map<ContractAddress, u256>,
        protocol_revenue: Map<ContractAddress, u256>,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        total_active_streams: u256,
        total_distributed: Map<ContractAddress, u256>,
        stream_metrics: Map<u256, StreamMetrics>,
        protocol_metrics: ProtocolMetrics,
        stream_delegates: Map<u256, ContractAddress>,
        delegation_history: Map<u256, Vec<ContractAddress>>,
        aggregate_balance: Map<ContractAddress, u256>,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        StreamRateUpdated: StreamRateUpdated,
        StreamCreated: StreamCreated,
        StreamWithdrawn: StreamWithdrawn,
        StreamCanceled: StreamCanceled,
        StreamPaused: StreamPaused,
        StreamRestarted: StreamRestarted,
        StreamVoided: StreamVoided,
        FeeCollected: FeeCollected,
        WithdrawalSuccessful: WithdrawalSuccessful,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        Src5Event: SRC5Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        DelegationGranted: DelegationGranted,
        DelegationRevoked: DelegationRevoked,
        StreamTransferabilitySet: StreamTransferabilitySet,
        StreamTransferred: StreamTransferred,
        ProtocolFeeSet: ProtocolFeeSet,
        ProtocolRevenueCollected: ProtocolRevenueCollected,
        StreamDeposit: StreamDeposit,
        Recover: Recover,
    }

    #[derive(Drop, starknet::Event)]
    struct StreamRateUpdated {
        #[key]
        stream_id: u256,
        old_rate: UFixedPoint123x128,
        new_rate: UFixedPoint123x128,
        update_time: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct FeeCollected {
        #[key]
        from: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct WithdrawalSuccessful {
        #[key]
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
        transferable: bool,
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
        rate_per_second: UFixedPoint123x128,
    }

    #[derive(Drop, starknet::Event)]
    struct StreamVoided {
        #[key]
        stream_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct DelegationGranted {
        #[key]
        stream_id: u256,
        delegator: ContractAddress,
        delegate: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct DelegationRevoked {
        #[key]
        stream_id: u256,
        delegator: ContractAddress,
        delegate: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct StreamTransferabilitySet {
        #[key]
        stream_id: u256,
        transferable: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct StreamTransferred {
        #[key]
        stream_id: u256,
        new_recipient: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct ProtocolFeeSet {
        #[key]
        token: ContractAddress,
        set_by: ContractAddress,
        new_fee: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct ProtocolRevenueCollected {
        #[key]
        token: ContractAddress,
        collected_by: ContractAddress,
        sent_to: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct StreamDeposit {
        #[key]
        stream_id: u256,
        funder: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Recover {
        #[key]
        pub sender: ContractAddress,
        pub to: ContractAddress,
        pub surplus: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, protocol_owner: ContractAddress) {
        self.accesscontrol.initializer();
        self.protocol_owner.write(protocol_owner);
        self.accesscontrol._grant_role(PROTOCOL_OWNER_ROLE, protocol_owner);
        self.erc721.initializer("PaymentStream", "STREAM", "https://paymentstream.io/");
    }

    /// @notice Calculates the rate of tokens per second for a stream
    /// @param total_amount The total amount of tokens to be streamed
    /// @param duration The duration of the stream in days
    /// @return The rate of tokens per second for the stream
    fn calculate_stream_rate(total_amount: u256, duration: u64) -> UFixedPoint123x128 {
        if duration == 0 {
            return 0_u64.into();
        }
        let num: UFixedPoint123x128 = total_amount.into();
        // Convert duration from days to seconds (86400 seconds in a day)
        let seconds_per_day: u64 = 86400;
        let duration_in_seconds: UFixedPoint123x128 = (duration * seconds_per_day)
            .try_into()
            .unwrap();
        let divisor: UFixedPoint123x128 = duration_in_seconds;
        // Calculate the rate by dividing the total amount by the duration in seconds
        // This gives us the rate of tokens per second for the stream
        let rate = num / divisor;
        return rate;
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_stream_exists(self: @ContractState, stream_id: u256) {
            let stream = self.streams.read(stream_id);
            assert(!stream.sender.is_zero(), UNEXISTING_STREAM);
        }

        fn assert_is_sender(self: @ContractState, stream_id: u256) {
            let stream = self.streams.read(stream_id);
            assert(get_caller_address() == stream.sender, WRONG_SENDER);
        }

        fn assert_is_recipient(self: @ContractState, stream_id: u256) {
            let recipient = self.erc721.owner_of(stream_id);
            assert(get_caller_address() == recipient, WRONG_RECIPIENT);
        }

        fn assert_is_transferable(self: @ContractState, stream_id: u256) {
            let stream = self.streams.read(stream_id);
            assert(stream.transferable, NON_TRANSFERABLE_STREAM);
        }

        /// @notice points basis: 100pbs = 1%
        fn calculate_protocol_fee(self: @ContractState, total_amount: u256) -> u256 {
            let protocol_fee_percentage = self.protocol_fee_percentage.read();
            let fee = (total_amount * protocol_fee_percentage.into()) / 10000;
            fee
        }

        fn collect_protocol_fee(self: @ContractState, token: ContractAddress, amount: u256) {
            let fee_collector: ContractAddress = self.fee_collector.read();
            assert(fee_collector.is_non_zero(), INVALID_RECIPIENT);
            IERC20Dispatcher { contract_address: token }.transfer(fee_collector, amount);
        }

        // Updated to check NFT ownership or delegate
        fn assert_is_recipient_or_delegate(self: @ContractState, stream_id: u256) {
            let caller = get_caller_address();
            let recipient = self.erc721.owner_of(stream_id);
            let approved = self.erc721.get_approved(stream_id);
            let delegate = self.stream_delegates.read(stream_id);
            assert(
                caller == recipient || caller == approved || caller == delegate,
                WRONG_RECIPIENT_OR_DELEGATE,
            );
        }

        fn _deposit(ref self: ContractState, stream_id: u256, amount: u256) {
            // Check: the stream exists
            self.assert_stream_exists(stream_id);

            // Check: the deposit amount is not zero
            assert(amount > 0, ZERO_AMOUNT);

            let mut stream = self.streams.read(stream_id);

            // Check: stream is not voided or canceled
            assert(stream.status != StreamStatus::Voided, 'Stream is voided');
            assert(stream.status != StreamStatus::Canceled, 'Stream is canceled');

            let token_address = stream.token;

            // Effect: update the stream balance by adding the deposit amount
            stream.balance += amount;
            self.streams.write(stream_id, stream);

            // Interaction: transfer the tokens from the sender to the contract
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            token_dispatcher.transfer_from(get_caller_address(), get_contract_address(), amount);

            // Log the deposit through an event
            self
                .emit(
                    Event::StreamDeposit(
                        StreamDeposit { stream_id, funder: get_caller_address(), amount },
                    ),
                );
        }

        fn _withdrawable_amount(self: @ContractState, stream_id: u256) -> u256 {
            // Retrieve the stream details
            let stream = self.streams.read(stream_id);

            // Get the current block timestamp
            let current_time = get_block_timestamp();

            // Calculate the elapsed time since the last update
            let elapsed_time = if current_time > stream.last_update_time {
                current_time - stream.last_update_time
            } else {
                0
            };

            // Calculate the withdrawable amount
            let elapsed_time_u256: u256 = elapsed_time.into();
            let rate_per_second_u256: u256 = stream.rate_per_second.into();
            let withdrawable = elapsed_time_u256 * rate_per_second_u256;

            // Return the withdrawable amount
            withdrawable
        }
    }

    #[abi(embed_v0)]
    impl PaymentStreamImpl of IPaymentStream<ContractState> {
        fn create_stream(
            ref self: ContractState,
            recipient: ContractAddress,
            total_amount: u256,
            duration: u64,
            cancelable: bool,
            token: ContractAddress,
            transferable: bool,
        ) -> u256 {
            assert(!recipient.is_zero(), INVALID_RECIPIENT);
            assert(total_amount > 0, ZERO_AMOUNT);
            assert(duration >= 1, TOO_SHORT_DURATION);
            assert(!token.is_zero(), INVALID_TOKEN);

            let stream_id = self.next_stream_id.read();
            self.next_stream_id.write(stream_id + 1);

            let erc20_dispatcher = IERC20MetadataDispatcher { contract_address: token };
            let token_decimals = erc20_dispatcher.decimals();
            assert(token_decimals <= 18, DECIMALS_TOO_HIGH);

            let rate_per_second = calculate_stream_rate(total_amount, duration);

            // Create new stream

            let stream = Stream {
                sender: get_caller_address(),
                token,
                token_decimals,
                total_amount,
                balance: 0,
                recipient,
                duration,
                withdrawn_amount: 0,
                cancelable,
                status: StreamStatus::Active,
                rate_per_second,
                last_update_time: get_block_timestamp(),
                transferable,
            };

            self.accesscontrol._grant_role(STREAM_ADMIN_ROLE, stream.sender);
            self.streams.write(stream_id, stream);
            self.erc721.mint(recipient, stream_id);

            let aggregate_balance = self.aggregate_balance.read(token) + total_amount;
            self.aggregate_balance.write(token, aggregate_balance);

            let protocol_metrics = self.protocol_metrics.read();
            self
                .protocol_metrics
                .write(
                    ProtocolMetrics {
                        total_active_streams: protocol_metrics.total_active_streams + 1,
                        total_tokens_to_stream: protocol_metrics.total_tokens_to_stream
                            + total_amount,
                        total_streams_created: protocol_metrics.total_streams_created + 1,
                        total_delegations: protocol_metrics.total_delegations,
                    },
                );

            self
                .emit(
                    Event::StreamCreated(
                        StreamCreated {
                            stream_id,
                            sender: get_caller_address(),
                            recipient,
                            total_amount,
                            token,
                            transferable,
                        },
                    ),
                );

            stream_id
        }

        /// @notice Creates a new stream and funds it with tokens in a single transaction
        /// @dev Combines the create_stream and deposit functions into one efficient operation
        fn create_stream_with_deposit(
            ref self: ContractState,
            recipient: ContractAddress,
            total_amount: u256,
            duration: u64,
            cancelable: bool,
            token: ContractAddress,
            transferable: bool,
        ) -> u256 {
            // Check token allowance first to avoid creating a stream we can't fund
            let caller = get_caller_address();
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            let allowance = token_dispatcher.allowance(caller, get_contract_address());

            // Ensure we have enough allowance for the deposit
            assert(allowance >= total_amount, INSUFFICIENT_ALLOWANCE);

            // Now create the stream as we know we have sufficient allowance
            let stream_id = self
                .create_stream(recipient, total_amount, duration, cancelable, token, transferable);

            // Transfer the tokens from the sender to the contract
            self._deposit(stream_id, total_amount);

            stream_id
        }

        fn deposit(ref self: ContractState, stream_id: u256, amount: u256) {
            // Call the internal deposit function
            self._deposit(stream_id, amount);
        }

        fn deposit_and_pause(ref self: ContractState, stream_id: u256, amount: u256) {
            // First deposit additional funds
            self._deposit(stream_id, amount);

            // Then pause the stream
            self.pause(stream_id);
        }

        fn transfer_stream(
            ref self: ContractState, stream_id: u256, new_recipient: ContractAddress,
        ) {
            // Verify stream exists
            self.assert_stream_exists(stream_id);

            // Verify the caller is the stream recipient
            self.assert_is_recipient(stream_id);

            // Verify the stream is transferable
            self.assert_is_transferable(stream_id);

            // Verify valid new recipient
            assert(new_recipient.is_non_zero(), INVALID_RECIPIENT);

            // Get current stream details
            let mut stream = self.streams.read(stream_id);

            // Update recipient
            stream.recipient = new_recipient;

            // Save updated stream
            self.streams.write(stream_id, stream);

            // Transfer the NFT to the new recipient
            let current_owner = self.erc721.owner_of(stream_id);
            self.erc721.transfer(current_owner, new_recipient, stream_id);

            // Emit event about stream transfer
            self.emit(StreamTransferred { stream_id, new_recipient });
        }

        fn set_transferability(ref self: ContractState, stream_id: u256, transferable: bool) {
            // Verify stream exists
            self.assert_stream_exists(stream_id);

            // Verify the caller is the stream owner (sender)
            self.assert_is_sender(stream_id);

            // Get current stream details
            let mut stream = self.streams.read(stream_id);

            // Update transferability if it's different from current setting
            if stream.transferable != transferable {
                stream.transferable = transferable;
            }
            // Save updated stream
            self.streams.write(stream_id, stream);

            // Emit event about transferability change
            self.emit(StreamTransferabilitySet { stream_id, transferable });
        }

        fn is_transferable(self: @ContractState, stream_id: u256) -> bool {
            // Get stream details
            let stream = self.streams.read(stream_id);

            // Return transferability status
            stream.transferable
        }

        fn withdraw(
            ref self: ContractState, stream_id: u256, amount: u256, to: ContractAddress,
        ) -> (u128, u128) {
            let mut stream = self.streams.read(stream_id);
            // @dev Allow stream creator to withdraw funds when a stream is canceled.
            if stream.sender != get_caller_address() {
                self.assert_is_recipient_or_delegate(stream_id);
            }

            let mut withdrawable_amount: u256 = 0;
            let debt_owned = self._withdrawable_amount(stream_id);

            let balance = stream.balance;

            if (balance < debt_owned) {
                withdrawable_amount = balance;
            } else {
                withdrawable_amount = debt_owned;
            }

            assert(withdrawable_amount >= amount, INSUFFICIENT_AMOUNT);
            assert(amount > 0, ZERO_AMOUNT);
            assert(to.is_non_zero(), INVALID_RECIPIENT);

            let fee = self.calculate_protocol_fee(amount);
            let net_amount: u256 = (amount - fee);
            let token_address = stream.token;
            let current_balance = stream.balance - stream.withdrawn_amount;
            // Check if current balance is sufficient for withdrawal
            assert(current_balance >= amount, INSUFFICIENT_AMOUNT);

            // Update stream's withdrawn amount
            stream.withdrawn_amount += amount;
            stream.balance -= amount;
            self.streams.write(stream_id, stream);

            let recipient = get_caller_address();
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

            self.collect_protocol_fee(token_address, fee);
            token_dispatcher.transfer(recipient, net_amount); // Transfer net amount to 'toAddress'

            let aggregate_balance = self.aggregate_balance.read(token_address) - amount;
            self.aggregate_balance.write(token_address, aggregate_balance);

            self
                .emit(
                    StreamWithdrawn {
                        stream_id, recipient: to, amount: net_amount, protocol_fee: fee.try_into().unwrap(),
                    },
                );

            (net_amount.try_into().unwrap(), fee.try_into().unwrap())
        }

        fn withdraw_max(
            ref self: ContractState, stream_id: u256, to: ContractAddress,
        ) -> (u128, u128) {
            let stream = self.streams.read(stream_id);
            // Allow stream creator to withdraw funds when a stream is canceled.
            if stream.sender != get_caller_address() {
                self.assert_is_recipient_or_delegate(stream_id);
            }

            let withdrawable_amount = self._withdrawable_amount(stream_id);
            assert(withdrawable_amount > 0, INSUFFICIENT_AMOUNT);
            assert(to.is_non_zero(), INVALID_RECIPIENT);

            let token_address = stream.token;
            let sender = stream.sender;
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let max_amount = token_dispatcher.balance_of(sender);
            let fee = self.calculate_protocol_fee(max_amount);
            let net_amount = (max_amount - fee);

            token_dispatcher.transfer_from(sender, to, net_amount);
            self.collect_protocol_fee(token_address, fee);

            let aggregate_balance = self.aggregate_balance.read(token_address) - net_amount;
            self.aggregate_balance.write(token_address, aggregate_balance);

            self
                .emit(
                    StreamWithdrawn {
                        stream_id, recipient: to, amount: net_amount, protocol_fee: fee.try_into().unwrap(),
                    },
                );

            (net_amount.try_into().unwrap(), fee.try_into().unwrap())
        }

        fn withdraw_protocol_fee(
            ref self: ContractState,
            recipient: ContractAddress,
            amount: u256,
            token: ContractAddress,
        ) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);
            assert(amount > 0, ZERO_AMOUNT);
            assert(recipient.is_non_zero(), INVALID_RECIPIENT);

            let fee_collector = self.fee_collector.read();
            let _success = IERC20Dispatcher { contract_address: token }
                .transfer_from(fee_collector, recipient, amount);
            assert(_success, 'token withdrawal fail...');

            let accumulated_fees = self.accumulated_fees.read(token);
            self.accumulated_fees.write(token, accumulated_fees - amount);

            let accumulated_fees = self.accumulated_fees.read(token);
            self.accumulated_fees.write(token, accumulated_fees - amount);

            self.emit(WithdrawalSuccessful { token, amount, recipient });
        }

        fn withdraw_max_protocol_fee(
            ref self: ContractState, recipient: ContractAddress, token: ContractAddress,
        ) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);
            assert(recipient.is_non_zero(), INVALID_RECIPIENT);

            let fee_collector = self.fee_collector.read();

            assert(fee_collector.is_non_zero(), INVALID_RECIPIENT);

            let max_amount = IERC20Dispatcher { contract_address: token }.balance_of(fee_collector);

            let _success = IERC20Dispatcher { contract_address: token }
                .transfer_from(fee_collector, recipient, max_amount);
            assert(_success, 'token withdrawal fail...');

            let accumulated_fees = self.accumulated_fees.read(token);
            self.accumulated_fees.write(token, accumulated_fees - max_amount);

            let aggregate_balance = self.aggregate_balance.read(token) - max_amount;
            self.aggregate_balance.write(token, aggregate_balance);

            self.emit(WithdrawalSuccessful { token, amount: max_amount, recipient });
        }

        fn update_percentage_protocol_fee(ref self: ContractState, new_percentage: u16) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);

            let protocol_fee_percentage = self.protocol_fee_percentage.read();
            assert(
                new_percentage > 0 && new_percentage != protocol_fee_percentage,
                'invalid fee percentage',
            );

            self.protocol_fee_percentage.write(new_percentage);
        }

        fn update_fee_collector(ref self: ContractState, new_fee_collector: ContractAddress) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);

            let fee_collector = self.fee_collector.read();
            assert(new_fee_collector.is_non_zero(), INVALID_RECIPIENT);
            assert(new_fee_collector != fee_collector, 'same collector address');

            self.fee_collector.write(new_fee_collector);
        }

        fn update_protocol_owner(ref self: ContractState, new_protocol_owner: ContractAddress) {
            let current_owner = self.protocol_owner.read();
            assert(new_protocol_owner.is_non_zero(), INVALID_RECIPIENT);
            assert(new_protocol_owner != current_owner, 'current owner == new_owner');

            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);

            self.protocol_owner.write(new_protocol_owner);

            self.accesscontrol.revoke_role(PROTOCOL_OWNER_ROLE, current_owner);
            self.accesscontrol._grant_role(PROTOCOL_OWNER_ROLE, new_protocol_owner);
        }

        fn get_fee_collector(self: @ContractState) -> ContractAddress {
            self.fee_collector.read()
        }

        fn cancel(ref self: ContractState, stream_id: u256) {
            // Ensure the caller has the STREAM_ADMIN_ROLE
            self.accesscontrol.assert_only_role(STREAM_ADMIN_ROLE);

            // Retrieve the stream
            let mut stream = self.streams.read(stream_id);
            let total_amount = stream.total_amount;
            let withdrawn_amount = stream.withdrawn_amount;

            // Ensure the stream is active before cancellation
            self.assert_stream_exists(stream_id);
            assert(stream.status == StreamStatus::Active, 'Stream is not Active');

            // Update the stream status to canceled
            stream.status = StreamStatus::Canceled;

            // Update Stream in State
            self.streams.write(stream_id, stream);

            self.erc721.burn(stream_id);

            // Calculate the amount that can be refunded
            let refundable_amount = total_amount - withdrawn_amount;

            if refundable_amount > 0 {
                self.refund(stream_id, refundable_amount);
            }

            // Emit an event for stream cancellation
            self.emit(StreamCanceled { stream_id });
        }

        fn pause(ref self: ContractState, stream_id: u256) {
            let mut stream = self.streams.read(stream_id);

            self.assert_stream_exists(stream_id);
            assert(stream.status != StreamStatus::Canceled, 'Stream is not active');

            stream.status = StreamStatus::Paused;
            self.streams.write(stream_id, stream);

            self.emit(StreamPaused { stream_id, pause_time: starknet::get_block_timestamp() });
        }

        fn restart(ref self: ContractState, stream_id: u256, rate_per_second: UFixedPoint123x128) {
            let mut stream = self.streams.read(stream_id);

            self.assert_stream_exists(stream_id);
            assert(stream.status != StreamStatus::Canceled, 'Stream is not active');

            stream.status = StreamStatus::Active;
            stream.rate_per_second = rate_per_second;
            self.streams.write(stream_id, stream);

            self.emit(StreamRestarted { stream_id, rate_per_second });
        }

        /// @notice Restart a paused stream and deposit funds to it in a single transaction
        /// @dev Combines the restart and deposit functions into one efficient operation
        /// @param stream_id The ID of the stream to restart and deposit to
        /// @param rate_per_second The new rate per second for the stream
        /// @param amount The amount to deposit into the stream
        /// @return Boolean indicating if the operation was successful
        fn restart_and_deposit(
            ref self: ContractState,
            stream_id: u256,
            rate_per_second: UFixedPoint123x128,
            amount: u256,
        ) -> bool {
            // First verify the stream exists and can be restarted
            self.assert_stream_exists(stream_id);

            // Get the current stream
            let mut stream = self.streams.read(stream_id);

            // Check that the stream is not canceled and is paused
            assert(stream.status != StreamStatus::Canceled, 'Stream is canceled');
            assert(stream.status == StreamStatus::Paused, 'Stream is not paused');

            // Check that the caller is the stream sender
            let caller = get_caller_address();
            assert(caller == stream.sender, WRONG_SENDER);

            // Check valid deposit amount
            assert(amount > 0, ZERO_AMOUNT);

            // Check token allowance before proceeding
            let token_address = stream.token;
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let allowance = token_dispatcher.allowance(caller, get_contract_address());
            assert(allowance >= amount, INSUFFICIENT_ALLOWANCE);

            // Restart the stream by setting status to active and updating rate
            stream.status = StreamStatus::Active;
            stream.rate_per_second = rate_per_second;
            stream.last_update_time = starknet::get_block_timestamp();

            // Update the total amount
            stream.total_amount += amount;

            // Save the updated stream
            self.streams.write(stream_id, stream);

            // Transfer the tokens from the sender to the contract
            token_dispatcher.transfer_from(caller, get_contract_address(), amount);

            // Update aggregate balance
            let aggregate_balance = self.aggregate_balance.read(token_address) + amount;
            self.aggregate_balance.write(token_address, aggregate_balance);

            // Emit the restart event
            self.emit(StreamRestarted { stream_id, rate_per_second });

            // Emit the deposit event
            self.emit(Event::StreamDeposit(StreamDeposit { stream_id, funder: caller, amount }));

            true
        }

        fn void(ref self: ContractState, stream_id: u256) {
            let mut stream = self.streams.read(stream_id);

            self.assert_stream_exists(stream_id);
            assert(stream.status != StreamStatus::Canceled, 'Stream is not active');

            stream.status = StreamStatus::Voided;
            self.streams.write(stream_id, stream);

            self.emit(StreamVoided { stream_id });
        }

        fn refund(ref self: ContractState, stream_id: u256, amount: u256) -> bool {
            // Read the stream data from storage
            let mut stream = self.streams.read(stream_id);
            let balance = stream.balance;

            //  // Ensure the caller Owner of the stream
            assert((get_caller_address() == stream.sender), 'Not your stream');

            // Check if the stream has been canceled before allowing a refund
            assert(stream.status == StreamStatus::Canceled, 'Stream is still active');

            // Ensure the stream exists before proceeding
            self.assert_stream_exists(stream_id);

            // Ensure the requested refund amount does not exceed the available balance
            assert(
                amount <= (stream.total_amount - stream.withdrawn_amount), 'Insufficient Balance',
            );

            let token_address = stream.token;
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

            let recipient = stream.sender;

            // Process the withdrawal to refund the specified amount to the contract address
            token_dispatcher.transfer(recipient, amount);

            // Indicate that the refund was successful
            true
        }

        fn refund_max(ref self: ContractState, stream_id: u256) -> bool {
            // Read the stream data from storage
            let mut stream = self.streams.read(stream_id);

            // Check if the stream has been canceled before allowing a refund
            assert(stream.status == StreamStatus::Canceled, 'Stream is still active');

            // Calculate the maximum refundable amount
            let amount: u256 = stream.total_amount - stream.withdrawn_amount;

            // Refund the maximum available amount from the stream
            self.refund(stream_id, amount);

            // Indicate that the refund operation was successful
            true
        }

        fn refund_and_pause(ref self: ContractState, stream_id: u256, amount: u256) -> bool {
            // Read the stream data from storage
            let mut stream = self.streams.read(stream_id);

            // Check if the stream has been canceled before allowing a refund
            assert(stream.status == StreamStatus::Active, 'Stream is still active');

            // Calculate the maximum refundable amount
            let amount: u256 = stream.total_amount - stream.withdrawn_amount;

            // Refund the maximum available amount from the stream
            self.refund(stream_id, amount);

            // Pause Stream
            self.pause(stream_id);

            // Indicate that the refund was successful
            true
        }

        fn get_stream(self: @ContractState, stream_id: u256) -> Stream {
            self.streams.read(stream_id)
        }

        fn get_withdrawable_amount(self: @ContractState, stream_id: u256) -> u256 {
            self._withdrawable_amount(stream_id)
        }

        fn is_stream_active(self: @ContractState, stream_id: u256) -> bool {
            // Return dummy status
            let mut stream = self.streams.read(stream_id);

            if (stream.status == StreamStatus::Active) {
                return true;
            } else {
                return false;
            }
        }

        fn get_depletion_time(self: @ContractState, stream_id: u256) -> u64 {
            // Return dummy timestamp
            0_u64
        }

        fn get_token_decimals(self: @ContractState, stream_id: u256) -> u8 {
            self.streams.read(stream_id).token_decimals
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

        fn get_active_streams_count(self: @ContractState) -> u256 {
            self.total_active_streams.read()
        }

        fn get_token_distribution(self: @ContractState, token: ContractAddress) -> u256 {
            self.total_distributed.read(token)
        }

        fn get_stream_metrics(self: @ContractState, stream_id: u256) -> StreamMetrics {
            self.stream_metrics.read(stream_id)
        }

        fn get_protocol_metrics(self: @ContractState) -> ProtocolMetrics {
            self.protocol_metrics.read()
        }

        fn delegate_stream(
            ref self: ContractState, stream_id: u256, delegate: ContractAddress,
        ) -> bool {
            self.assert_stream_exists(stream_id);
            self.assert_is_sender(stream_id);
            assert(delegate.is_non_zero(), INVALID_RECIPIENT);
            self.stream_delegates.write(stream_id, delegate);
            self.delegation_history.entry(stream_id).push(delegate);
            self.emit(DelegationGranted { stream_id, delegator: get_caller_address(), delegate });
            true
        }

        fn revoke_delegation(ref self: ContractState, stream_id: u256) -> bool {
            self.assert_stream_exists(stream_id);
            self.assert_is_sender(stream_id);
            let delegate = self.stream_delegates.read(stream_id);
            assert(delegate.is_non_zero(), UNEXISTING_STREAM);
            self.stream_delegates.write(stream_id, 0.try_into().unwrap());
            self.emit(DelegationRevoked { stream_id, delegator: get_caller_address(), delegate });
            true
        }

        fn get_stream_delegate(self: @ContractState, stream_id: u256) -> ContractAddress {
            self.stream_delegates.read(stream_id)
        }

        fn update_stream_rate(
            ref self: ContractState, stream_id: u256, new_rate_per_second: UFixedPoint123x128,
        ) {
            let caller = get_caller_address();
            let zero_amount: UFixedPoint123x128 = 0.into();
            let total = new_rate_per_second + zero_amount;
            let z: u256 = total.into();
            assert(z > 0, ZERO_AMOUNT);
            assert(self.streams.read(stream_id).sender == caller, WRONG_SENDER);

            let stream: Stream = self.streams.read(stream_id);
            assert!(stream.status == StreamStatus::Active, "Stream is not active");

            let new_stream = Stream {
                rate_per_second: new_rate_per_second,
                sender: stream.sender,
                recipient: stream.recipient,
                token: stream.token,
                token_decimals: stream.token_decimals,
                total_amount: stream.total_amount,
                balance: stream.balance,
                duration: stream.duration,
                withdrawn_amount: stream.withdrawn_amount,
                cancelable: stream.cancelable,
                status: stream.status,
                last_update_time: starknet::get_block_timestamp(),
                transferable: stream.transferable,
            };

            self.streams.write(stream_id, new_stream);
            self
                .emit(
                    Event::StreamRateUpdated(
                        StreamRateUpdated {
                            stream_id,
                            old_rate: stream.rate_per_second,
                            new_rate: new_rate_per_second,
                            update_time: starknet::get_block_timestamp(),
                        },
                    ),
                );
        }
        fn get_protocol_fee(self: @ContractState, token: ContractAddress) -> u256 {
            self.protocol_fees.read(token)
        }

        fn get_protocol_revenue(self: @ContractState, token: ContractAddress) -> u256 {
            self.protocol_revenue.read(token)
        }

        fn collect_protocol_revenue(
            ref self: ContractState, token: ContractAddress, to: ContractAddress,
        ) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);
            let protocol_revenue = self.protocol_revenue.read(token);
            self.protocol_revenue.write(token, 0_u256);
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            token_dispatcher.transfer(to, protocol_revenue);

            let aggregate_balance = self.aggregate_balance.read(token) - protocol_revenue;
            self.aggregate_balance.write(token, aggregate_balance);

            self
                .emit(
                    ProtocolRevenueCollected {
                        token,
                        collected_by: get_caller_address(),
                        sent_to: to,
                        amount: protocol_revenue,
                    },
                )
        }

        fn set_protocol_fee(
            ref self: ContractState, token: ContractAddress, new_protocol_fee: u256,
        ) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);
            assert(new_protocol_fee <= MAX_FEE, 'fee too high');
            self.protocol_fees.write(token, new_protocol_fee);
            self
                .emit(
                    ProtocolFeeSet {
                        token, set_by: get_caller_address(), new_fee: new_protocol_fee,
                    },
                );
        }

        fn is_stream(self: @ContractState, stream_id: u256) -> bool {
            let stream: Stream = self.streams.read(stream_id);
            if stream.status == StreamStatus::Active {
                return true;
            }
            false
        }

        fn is_paused(self: @ContractState, stream_id: u256) -> bool {
            let stream: Stream = self.streams.read(stream_id);
            if stream.status == StreamStatus::Paused {
                return true;
            }
            false
        }

        fn is_voided(self: @ContractState, stream_id: u256) -> bool {
            let stream: Stream = self.streams.read(stream_id);
            if stream.status == StreamStatus::Voided {
                return true;
            }
            false
        }

        fn get_sender(self: @ContractState, stream_id: u256) -> ContractAddress {
            let stream: Stream = self.streams.read(stream_id);

            return stream.sender;
        }

        fn get_recipient(self: @ContractState, stream_id: u256) -> ContractAddress {
            self.erc721.owner_of(stream_id)
        }

        fn get_token(self: @ContractState, stream_id: u256) -> ContractAddress {
            let stream: Stream = self.streams.read(stream_id);

            return stream.token;
        }

        fn get_rate_per_second(self: @ContractState, stream_id: u256) -> UFixedPoint123x128 {
            let stream: Stream = self.streams.read(stream_id);

            return stream.rate_per_second;
        }

        fn aggregate_balance(self: @ContractState, token: ContractAddress) -> u256 {
            self.aggregate_balance.read(token)
        }

        fn recover(ref self: ContractState, token: ContractAddress, to: ContractAddress) -> u256 {
            assert(!to.is_zero(), INVALID_RECIPIENT);
            assert(!token.is_zero(), INVALID_TOKEN);
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);

            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            let surplus = token_dispatcher.balance_of(get_contract_address())
                - self.aggregate_balance.read(token);

            assert(surplus > 0, ZERO_AMOUNT);

            token_dispatcher.transfer(to, surplus);

            self.emit(Recover { sender: get_contract_address(), to, surplus });

            surplus
        }
    }
}
