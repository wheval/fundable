#[starknet::contract]
pub mod PaymentStream {
    use core::num::traits::Zero;
    use core::traits::Into;
    use fundable::interfaces::IPaymentStream::IPaymentStream;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{
        IERC20Dispatcher, IERC20DispatcherTrait, IERC20MetadataDispatcher,
        IERC20MetadataDispatcherTrait,
    };
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec,
    };
    use starknet::{
        ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address,
    };
    use crate::base::errors::Errors::{
        DECIMALS_TOO_HIGH, FEE_TOO_HIGH, INSUFFICIENT_ALLOWANCE, INSUFFICIENT_AMOUNT,
        INVALID_RECIPIENT, INVALID_TOKEN, NON_TRANSFERABLE_STREAM, ONLY_NFT_OWNER_CAN_DELEGATE,
        SAME_COLLECTOR_ADDRESS, SAME_OWNER, STREAM_CANCELED, STREAM_HAS_DELEGATE, STREAM_NOT_ACTIVE,
        STREAM_NOT_PAUSED, STREAM_VOIDED, TOO_SHORT_DURATION, UNEXISTING_STREAM, WRONG_RECIPIENT,
        WRONG_RECIPIENT_OR_DELEGATE, WRONG_SENDER, ZERO_AMOUNT,
    };
    use crate::base::types::{ProtocolMetrics, Stream, StreamMetrics, StreamStatus};

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: Src5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    const PROTOCOL_OWNER_ROLE: felt252 = selector!("PROTOCOL_OWNER");
    const STREAM_ADMIN_ROLE: felt252 = selector!("STREAM_ADMIN");

    const MAX_FEE: u256 = 5000;
    const SECONDS_PER_DAY: u64 = 86400;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        next_stream_id: u256,
        streams: Map<u256, Stream>,
        protocol_fee_rate: Map<ContractAddress, u256>, // Single source of truth for fee rates
        fee_collector: ContractAddress,
        protocol_owner: ContractAddress,
        protocol_revenue: Map<ContractAddress, u256>, // Track collected fees
        total_active_streams: u256,
        stream_metrics: Map<u256, StreamMetrics>,
        protocol_metrics: ProtocolMetrics,
        stream_delegates: Map<u256, ContractAddress>,
        delegation_history: Map<u256, Vec<ContractAddress>>,
        aggregate_balance: Map<ContractAddress, u256>,
        snapshot_debt: Map<u256, u256>,
        snapshot_time: Map<u256, u64>,
        paused_rates: Map<u256, u256>,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        Src5Event: SRC5Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        StreamCreated: StreamCreated,
        StreamWithdrawn: StreamWithdrawn,
        StreamCanceled: StreamCanceled,
        StreamPaused: StreamPaused,
        StreamRestarted: StreamRestarted,
        StreamVoided: StreamVoided,
        FeeCollected: FeeCollected,
        WithdrawalSuccessful: WithdrawalSuccessful,
        DelegationGranted: DelegationGranted,
        DelegationRevoked: DelegationRevoked,
        StreamTransferabilitySet: StreamTransferabilitySet,
        StreamTransferred: StreamTransferred,
        ProtocolFeeSet: ProtocolFeeSet,
        ProtocolRevenueCollected: ProtocolRevenueCollected,
        StreamDeposit: StreamDeposit,
        Recover: Recover,
        RefundFromStream: RefundFromStream,
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
        rate_per_second: u256,
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

    #[derive(Drop, starknet::Event)]
    struct RefundFromStream {
        #[key]
        stream_id: u256,
        sender: ContractAddress,
        amount: u256,
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
    fn calculate_stream_rate(total_amount: u256, duration: u64) -> u256 {
        if duration == 0 {
            return 0_u64.into();
        }
        let num = total_amount;
        // Convert duration from days to seconds (86400 seconds in a day)
        let duration_in_seconds = (duration * SECONDS_PER_DAY);
        let divisor = duration_in_seconds;
        // Calculate the rate by dividing the total amount by the duration in seconds
        // This gives us the rate of tokens per second for the stream
        let rate = num / divisor.into();
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

        /// @notice Calculates the protocol fee using fixed-point arithmetic
        /// @param amount The amount to calculate fee from
        /// @param token_address The token address to get fee rate for
        /// @return The protocol fee amount
        fn _calculate_protocol_fee(
            self: @ContractState, amount: u256, token_address: ContractAddress,
        ) -> u256 {
            let fee_rate = self.protocol_fee_rate.read(token_address);
            assert(fee_rate <= MAX_FEE, FEE_TOO_HIGH);

            let rate = if fee_rate == 0 {
                100 // 1% = 100 basis points
            } else {
                fee_rate
            };

            // Calculate fee using fixed-point multiplication
            let fee = (amount * rate) / 10000_u256; // Assuming 10000 = 100%
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
            assert(stream.status != StreamStatus::Voided, STREAM_VOIDED);
            assert(stream.status != StreamStatus::Canceled, STREAM_CANCELED);

            let token_address = stream.token;

            // Effect: update the stream balance by adding the deposit amount
            stream.balance += amount;
            self.streams.write(stream_id, stream);

            // Update stream metrics
            let mut metrics = self.stream_metrics.read(stream_id);
            metrics.total_deposited += amount;
            metrics.last_activity = get_block_timestamp();
            self.stream_metrics.write(stream_id, metrics);

            let aggregate_balance = self.aggregate_balance.read(token_address) + amount;
            self.aggregate_balance.write(token_address, aggregate_balance);

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

        /// @notice Calculates the ongoing debt since last snapshot
        /// @param stream_id The ID of the stream
        /// @return The ongoing debt in scaled form
        fn _ongoing_debt_scaled(self: @ContractState, stream_id: u256) -> u256 {
            let current_time = get_block_timestamp();
            let snapshot_time = self.snapshot_time.read(stream_id);
            let stream = self.streams.read(stream_id);

            // If stream is paused or current time is before snapshot time, return 0
            if stream.status != StreamStatus::Active || current_time <= snapshot_time {
                return 0_u256;
            }

            // Calculate elapsed time since last snapshot
            let elapsed_time = (current_time - snapshot_time).into();

            // Calculate ongoing debt by multiplying elapsed time by rate per second
            let rate_per_second: u256 = stream.rate_per_second.into();
            elapsed_time * rate_per_second
        }

        /// @notice Calculates the total debt of a stream
        /// @param stream_id The ID of the stream
        /// @return The total debt in token decimals
        fn _total_debt(self: @ContractState, stream_id: u256) -> u256 {
            let stream = self.streams.read(stream_id);
            let duration_in_seconds = stream.duration * SECONDS_PER_DAY;
            let duration_passed = get_block_timestamp() - stream.first_update_time;

            if duration_passed >= duration_in_seconds {
                return stream.balance;
            }

            let ongoing_debt_scaled = self._ongoing_debt_scaled(stream_id);
            let snapshot_debt_scaled = self.snapshot_debt.read(stream_id);

            // Total debt in scaled form
            let total_debt_scaled = ongoing_debt_scaled + snapshot_debt_scaled;

            // Convert from scaled form to token decimals
            total_debt_scaled
        }

        /// @notice Updates the snapshot for a stream
        /// @param stream_id The ID of the stream
        fn _update_snapshot(ref self: ContractState, stream_id: u256) {
            let ongoing_debt_scaled = self._ongoing_debt_scaled(stream_id);
            if ongoing_debt_scaled > 0 {
                let current_snapshot_debt = self.snapshot_debt.read(stream_id);
                self.snapshot_debt.write(stream_id, current_snapshot_debt + ongoing_debt_scaled);
            }
            self.snapshot_time.write(stream_id, get_block_timestamp());
        }

        /// @notice Calculates the withdrawable amount for a stream
        /// @param stream_id The ID of the stream
        /// @return The withdrawable amount
        fn _withdrawable_amount(self: @ContractState, stream_id: u256) -> u256 {
            let stream = self.streams.read(stream_id);
            let total_debt = self._total_debt(stream_id);

            // For paused streams, calculate debt up to the pause time
            if stream.status == StreamStatus::Paused {
                // first_updated_time - last_updated_time
                let pause_time = stream.last_update_time - stream.first_update_time;

                // Calculate elapsed time from last snapshot to pause time
                let elapsed_time = pause_time;

                // Calculate debt up to pause time
                let rate_per_second: u256 = stream.rate_per_second.into();
                let pause_debt: u256 = elapsed_time.into() * rate_per_second;

                // The withdrawable amount is the minimum of stream balance and total pause debt
                if stream.balance < pause_debt {
                    stream.balance
                } else {
                    pause_debt
                }
            } else {
                // For active streams, the withdrawable amount is the minimum of stream balance and
                // total debt
                if stream.balance <= total_debt {
                    stream.balance
                } else {
                    total_debt
                }
            }
        }

        /// @notice Sets the protocol fee rate for a token
        /// @param token The token address
        /// @param new_fee_rate The new fee rate in basis points (e.g., 100 = 1%)
        fn _set_protocol_fee_rate(
            ref self: ContractState, token: ContractAddress, new_fee_rate: u256,
        ) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);
            assert(new_fee_rate <= MAX_FEE, FEE_TOO_HIGH);

            let current_fee_rate = self.protocol_fee_rate.read(token);
            if current_fee_rate != new_fee_rate {
                self.protocol_fee_rate.write(token, new_fee_rate);

                self
                    .emit(
                        ProtocolFeeSet {
                            token, set_by: get_caller_address(), new_fee: new_fee_rate,
                        },
                    );
            }
        }

        /// @notice Internal function to handle withdrawals
        /// @param stream_id The ID of the stream to withdraw from
        /// @param amount The amount to withdraw
        /// @param to The address receiving the withdrawn tokens
        /// @return A tuple of (withdrawn_amount, protocol_fee_amount)
        fn _withdraw(
            ref self: ContractState, stream_id: u256, amount: u256, to: ContractAddress,
        ) -> (u128, u128) {
            let mut stream = self.streams.read(stream_id);
            // @dev Allow stream creator to withdraw funds when a stream is canceled.
            if stream.sender != get_caller_address() {
                self.assert_is_recipient_or_delegate(stream_id);
            }

            // Update snapshot before calculating withdrawable amount
            self._update_snapshot(stream_id);

            let withdrawable_amount = self._withdrawable_amount(stream_id);
            assert(withdrawable_amount >= amount, INSUFFICIENT_AMOUNT);
            assert(amount > 0, ZERO_AMOUNT);
            assert(to.is_non_zero(), INVALID_RECIPIENT);

            // Calculate fee using new fixed-point system
            let token_address = stream.token;
            let fee = self._calculate_protocol_fee(amount, token_address);
            let net_amount: u256 = (amount - fee);
            let current_balance = stream.balance - stream.withdrawn_amount;

            // Check if current balance is sufficient for withdrawal
            assert(current_balance >= amount, INSUFFICIENT_AMOUNT);

            // Update stream's withdrawn amount and balance
            stream.withdrawn_amount += amount;
            stream.balance -= amount;
            self.streams.write(stream_id, stream);

            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

            self.collect_protocol_fee(token_address, fee);
            token_dispatcher.transfer(to, net_amount);

            let aggregate_balance = self.aggregate_balance.read(token_address) - amount;
            self.aggregate_balance.write(token_address, aggregate_balance);

            // Update snapshot after withdrawal
            self._update_snapshot(stream_id);

            // Update stream metrics
            let mut metrics = self.stream_metrics.read(stream_id);
            metrics.total_withdrawn += amount;
            metrics.withdrawal_count += 1;
            metrics.last_activity = get_block_timestamp();
            self.stream_metrics.write(stream_id, metrics);

            self
                .emit(
                    StreamWithdrawn {
                        stream_id,
                        recipient: to,
                        amount: net_amount,
                        protocol_fee: fee.try_into().unwrap(),
                    },
                );

            (net_amount.try_into().unwrap(), fee.try_into().unwrap())
        }

        /// @notice Internal function to handle refunds to stream creator
        /// @param stream_id The ID of the stream to refund from
        /// @param amount The amount to refund
        fn _refund(ref self: ContractState, stream_id: u256, amount: u256) {
            let stream = self.streams.read(stream_id);
            let token_address = stream.token;
            let sender = stream.sender;

            // Transfer tokens back to sender
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            token_dispatcher.transfer(sender, amount);

            // Update aggregate balance
            let aggregate_balance = self.aggregate_balance.read(token_address) - amount;
            self.aggregate_balance.write(token_address, aggregate_balance);

            // Emit event
            self.emit(RefundFromStream { stream_id, sender, amount });
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
                first_update_time: get_block_timestamp(),
            };

            self.snapshot_time.write(stream_id, get_block_timestamp());

            // Initialize stream metrics
            let metrics = StreamMetrics {
                last_activity: get_block_timestamp(),
                total_withdrawn: 0,
                total_deposited: 0,
                withdrawal_count: 0,
                pause_count: 0,
                total_delegations: 0,
                current_delegate: 0.try_into().unwrap(),
                last_delegation_time: 0,
            };

            self.accesscontrol._grant_role(STREAM_ADMIN_ROLE, stream.sender);
            self.streams.write(stream_id, stream);
            self.stream_metrics.write(stream_id, metrics);
            self.erc721.mint(recipient, stream_id);

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

        fn withdraw(
            ref self: ContractState, stream_id: u256, amount: u256, to: ContractAddress,
        ) -> (u128, u128) {
            self._withdraw(stream_id, amount, to)
        }

        fn withdraw_max(
            ref self: ContractState, stream_id: u256, to: ContractAddress,
        ) -> (u128, u128) {
            let withdrawable_amount = self._withdrawable_amount(stream_id);
            self._withdraw(stream_id, withdrawable_amount, to)
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

        fn update_fee_collector(ref self: ContractState, new_fee_collector: ContractAddress) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);

            let fee_collector = self.fee_collector.read();
            assert(new_fee_collector.is_non_zero(), INVALID_RECIPIENT);
            assert(new_fee_collector != fee_collector, SAME_COLLECTOR_ADDRESS);

            self.fee_collector.write(new_fee_collector);
        }

        fn update_protocol_owner(ref self: ContractState, new_protocol_owner: ContractAddress) {
            let current_owner = self.protocol_owner.read();
            assert(new_protocol_owner.is_non_zero(), INVALID_RECIPIENT);
            assert(new_protocol_owner != current_owner, SAME_OWNER);

            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);

            self.protocol_owner.write(new_protocol_owner);

            self.accesscontrol.revoke_role(PROTOCOL_OWNER_ROLE, current_owner);
            self.accesscontrol._grant_role(PROTOCOL_OWNER_ROLE, new_protocol_owner);
        }

        fn get_fee_collector(self: @ContractState) -> ContractAddress {
            self.fee_collector.read()
        }

        fn pause(ref self: ContractState, stream_id: u256) {
            // Ensure the caller has the STREAM_ADMIN_ROLE
            self.accesscontrol.assert_only_role(STREAM_ADMIN_ROLE);
            let mut stream = self.streams.read(stream_id);

            self.assert_stream_exists(stream_id);
            assert(stream.status != StreamStatus::Canceled, STREAM_NOT_ACTIVE);

            // Only decrement counter if stream was active
            if stream.status == StreamStatus::Active {
                let protocol_metrics = self.protocol_metrics.read();
                self
                    .protocol_metrics
                    .write(
                        ProtocolMetrics {
                            total_active_streams: protocol_metrics.total_active_streams - 1,
                            total_tokens_to_stream: protocol_metrics.total_tokens_to_stream,
                            total_streams_created: protocol_metrics.total_streams_created,
                            total_delegations: protocol_metrics.total_delegations,
                        },
                    );
            }

            // Store the current rate before pausing
            self.paused_rates.write(stream_id, stream.rate_per_second);

            // Update the last update time to current block timestamp
            stream.last_update_time = get_block_timestamp();
            let pause_time = stream.last_update_time;

            // Set rate to zero and update status
            stream.rate_per_second = 0_u64.into();
            stream.status = StreamStatus::Paused;
            self.streams.write(stream_id, stream);

            // Update stream metrics
            let mut metrics = self.stream_metrics.read(stream_id);
            metrics.pause_count += 1;
            metrics.last_activity = get_block_timestamp();
            self.stream_metrics.write(stream_id, metrics);

            self.emit(StreamPaused { stream_id, pause_time: pause_time });
        }

        fn cancel(ref self: ContractState, stream_id: u256) {
            // Ensure the caller has the STREAM_ADMIN_ROLE
            self.accesscontrol.assert_only_role(STREAM_ADMIN_ROLE);

            // Retrieve the stream
            let mut stream = self.streams.read(stream_id);

            let stream_balance = stream.balance;

            // Ensure the stream is active before cancellation
            self.assert_stream_exists(stream_id);

            // Only decrement counter if stream was active
            if stream.status == StreamStatus::Active {
                let protocol_metrics = self.protocol_metrics.read();
                self
                    .protocol_metrics
                    .write(
                        ProtocolMetrics {
                            total_active_streams: protocol_metrics.total_active_streams - 1,
                            total_tokens_to_stream: protocol_metrics.total_tokens_to_stream,
                            total_streams_created: protocol_metrics.total_streams_created,
                            total_delegations: protocol_metrics.total_delegations,
                        },
                    );
            }

            // Update snapshot before calculations
            self._update_snapshot(stream_id);

            // Calculate total debt (amount streamed but not withdrawn)
            let total_debt = self._total_debt(stream_id);

            // Update the stream status to canceled
            stream.status = StreamStatus::Canceled;

            // Update Stream in State
            self.streams.write(stream_id, stream);

            self.erc721.burn(stream_id);

            // Calculate the amount that can be refunded
            // This ensures the recipient gets what they're owed (total_debt)
            // and the sender gets back any excess funds (balance - total_debt)
            let refundable_amount = if stream_balance > total_debt {
                stream_balance - total_debt
            } else {
                0_u256
            };

            if refundable_amount > 0 {
                // Use the dedicated refund function
                self._refund(stream_id, refundable_amount);
            }

            // Emit an event for stream cancellation
            self.emit(StreamCanceled { stream_id });
        }

        fn restart(ref self: ContractState, stream_id: u256) {
            // Ensure the caller has the STREAM_ADMIN_ROLE
            self.accesscontrol.assert_only_role(STREAM_ADMIN_ROLE);
            let mut stream = self.streams.read(stream_id);

            self.assert_stream_exists(stream_id);
            assert(stream.status != StreamStatus::Canceled, STREAM_NOT_ACTIVE);

            // Only increment counter if stream was paused
            assert(stream.status == StreamStatus::Paused, STREAM_NOT_PAUSED);

            let protocol_metrics = self.protocol_metrics.read();
            self
                .protocol_metrics
                .write(
                    ProtocolMetrics {
                        total_active_streams: protocol_metrics.total_active_streams + 1,
                        total_tokens_to_stream: protocol_metrics.total_tokens_to_stream,
                        total_streams_created: protocol_metrics.total_streams_created,
                        total_delegations: protocol_metrics.total_delegations,
                    },
                );

            // Get the stored rate from when the stream was paused
            let stored_rate = self.paused_rates.read(stream_id);

            // Update stream with new rate, status, and current timestamp
            stream.rate_per_second = stored_rate;
            stream.status = StreamStatus::Active;
            stream.last_update_time = get_block_timestamp();
            self.streams.write(stream_id, stream);

            // Clear the stored rate
            self.paused_rates.write(stream_id, 0_u64.into());

            self.emit(StreamRestarted { stream_id, rate_per_second: stored_rate });
        }

        /// @notice Restart a paused stream and deposit funds to it in a single transaction
        /// @dev Combines the restart and deposit functions into one efficient operation
        /// @param stream_id The ID of the stream to restart and deposit to
        /// @param amount The amount to deposit into the stream
        /// @return Boolean indicating if the operation was successful
        fn restart_and_deposit(ref self: ContractState, stream_id: u256, amount: u256) -> bool {
            // First restart the stream
            self.restart(stream_id);

            // Then deposit the funds
            self.deposit(stream_id, amount);

            true
        }

        fn void(ref self: ContractState, stream_id: u256) {
            let mut stream = self.streams.read(stream_id);

            self.assert_stream_exists(stream_id);
            assert(stream.status != StreamStatus::Canceled, STREAM_NOT_ACTIVE);

            stream.status = StreamStatus::Voided;
            self.streams.write(stream_id, stream);

            self.emit(StreamVoided { stream_id });
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
            let stream = self.streams.read(stream_id);

            // If stream is not active or has no rate, return 0
            if stream.status != StreamStatus::Active || stream.rate_per_second == 0_u256 {
                return 0_u64;
            }

            // Get current time and calculate remaining balance
            let current_time = get_block_timestamp();
            let total_debt = self._total_debt(stream_id);

            // If balance is less than or equal to total debt, stream is already depleted
            if stream.balance <= total_debt {
                return current_time;
            }

            let remaining_balance = stream.balance - total_debt;
            let rate_per_second = stream.rate_per_second;

            // Calculate seconds until depletion using fixed point arithmetic to avoid rounding
            // errors
            let seconds_until_depletion: u64 = (remaining_balance / rate_per_second)
                .try_into()
                .unwrap();

            seconds_until_depletion
        }

        fn get_token_decimals(self: @ContractState, stream_id: u256) -> u8 {
            self.streams.read(stream_id).token_decimals
        }

        fn get_total_debt(self: @ContractState, stream_id: u256) -> u256 {
            self._total_debt(stream_id)
        }

        fn get_uncovered_debt(self: @ContractState, stream_id: u256) -> u256 {
            let stream = self.streams.read(stream_id);
            let total_debt = self._total_debt(stream_id);

            // If total debt is greater than balance, return the difference
            // Otherwise return 0 (all debt is covered)
            if total_debt > stream.balance {
                total_debt - stream.balance
            } else {
                0_u256
            }
        }

        fn get_covered_debt(self: @ContractState, stream_id: u256) -> u256 {
            let stream = self.streams.read(stream_id);
            let total_debt = self._total_debt(stream_id);

            // If balance is greater than total debt, all debt is covered
            // Otherwise, the balance amount is covered
            if stream.balance >= total_debt {
                total_debt
            } else {
                stream.balance
            }
        }

        fn get_refundable_amount(self: @ContractState, stream_id: u256) -> u256 {
            let stream = self.streams.read(stream_id);

            // If stream is not active, return 0
            if stream.status != StreamStatus::Active {
                return 0_u256;
            }

            // Calculate total debt (amount streamed but not withdrawn)
            let total_debt = self._total_debt(stream_id);

            // Calculate refundable amount as the excess balance after accounting for debt
            if stream.balance > total_debt {
                stream.balance - total_debt
            } else {
                0_u256
            }
        }

        fn get_active_streams_count(self: @ContractState) -> u256 {
            self.protocol_metrics.read().total_active_streams
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
            assert(delegate.is_non_zero(), INVALID_RECIPIENT);

            // Check NFT ownership instead of recipient field
            let nft_owner = self.erc721.owner_of(stream_id);
            assert(nft_owner == get_caller_address(), ONLY_NFT_OWNER_CAN_DELEGATE);

            let current_delegate = self.stream_delegates.read(stream_id);
            assert(current_delegate.is_zero(), STREAM_HAS_DELEGATE);

            self.stream_delegates.write(stream_id, delegate);
            self.delegation_history.entry(stream_id).push(delegate);

            // Update stream metrics
            let mut metrics = self.stream_metrics.read(stream_id);
            metrics.total_delegations += 1;
            metrics.current_delegate = delegate;
            metrics.last_delegation_time = get_block_timestamp();
            metrics.last_activity = get_block_timestamp();
            self.stream_metrics.write(stream_id, metrics);

            // Update protocol metrics
            let mut protocol_metrics = self.protocol_metrics.read();
            protocol_metrics.total_delegations += 1;
            self.protocol_metrics.write(protocol_metrics);

            self.emit(DelegationGranted { stream_id, delegator: get_caller_address(), delegate });
            true
        }

        fn revoke_delegation(ref self: ContractState, stream_id: u256) -> bool {
            self.assert_stream_exists(stream_id);
            self.assert_is_recipient(stream_id);
            let delegate = self.stream_delegates.read(stream_id);
            assert(delegate.is_non_zero(), UNEXISTING_STREAM);
            self.stream_delegates.write(stream_id, 0.try_into().unwrap());
            self.emit(DelegationRevoked { stream_id, delegator: get_caller_address(), delegate });
            true
        }

        fn get_stream_delegate(self: @ContractState, stream_id: u256) -> ContractAddress {
            self.stream_delegates.read(stream_id)
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

        fn get_rate_per_second(self: @ContractState, stream_id: u256) -> u256 {
            let stream = self.streams.read(stream_id);
            let rate = stream.rate_per_second.into();
            rate
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

        /// @notice Sets the protocol fee rate for a specific token
        /// @param token The token address to set the fee rate for
        /// @param new_fee_rate The new fee rate in basis points (e.g., 100 = 1%)
        fn set_protocol_fee_rate(
            ref self: ContractState, token: ContractAddress, new_fee_rate: u256,
        ) {
            self._set_protocol_fee_rate(token, new_fee_rate);
        }

        /// @notice Gets the protocol fee rate for a specific token
        /// @param token The token address to get the fee rate for
        /// @return The current fee rate in basis points
        fn get_protocol_fee_rate(self: @ContractState, token: ContractAddress) -> u256 {
            self.protocol_fee_rate.read(token)
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
