/// Main contract implementation
#[starknet::contract]
mod Distributor {
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::ContractAddress;
    use core::traits::Into;
    use starknet::{get_block_timestamp, get_caller_address, get_contract_address, ClassHash};
    use starknet::storage::{Map};
    use core::num::traits::Zero;
    use crate::base::types::{
        DistributionHistory, Distribution, WeightedDistribution, TokenStats, UserStats
    };
    //  use super::Errors;
    use crate::base::errors::Errors::{
        EMPTY_RECIPIENTS, ZERO_AMOUNT, INSUFFICIENT_ALLOWANCE, INVALID_TOKEN, ARRAY_LEN_MISMATCH,
    };
    use fundable::interfaces::IDistributor::IDistributor;
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        balance: u256,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        total_distributions: u256,
        total_distributed_amount: u256,
        token_stats: Map<ContractAddress, TokenStats>,
        user_stats: Map<ContractAddress, UserStats>,
        distribution_history: Map<u256, DistributionHistory>,
        distribution_count: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Distribution: Distribution,
        WeightedDistribution: WeightedDistribution,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn update_global_stats(ref self: ContractState, total_amount: u256) {
            let current_total_distributions = self.total_distributions.read();
            self.total_distributions.write(current_total_distributions + 1);

            let current_total_distributed_amount = self.total_distributed_amount.read();
            self.total_distributed_amount.write(current_total_distributed_amount + total_amount);
        }

        fn update_token_stats(
            ref self: ContractState, token: ContractAddress, amount: u256, recipients_count: u32,
        ) {
            let mut stats = self.token_stats.read(token);
            stats.total_amount += amount;
            stats.distribution_count += 1;
            stats.last_distribution_time = get_block_timestamp();

            self.token_stats.write(token, stats);
        }

        fn update_user_stats(
            ref self: ContractState,
            user: ContractAddress,
            total_amount: u256,
            token: ContractAddress,
        ) {
            let mut stats = self.user_stats.read(user);
            stats.distributions_initiated += 1;
            stats.total_amount_distributed += total_amount;
            stats.unique_tokens_used += 1;
            stats.last_distribution_time = get_block_timestamp();
            self.user_stats.write(user, stats);
        }

        fn record_distribution(ref self: ContractState, distribution: DistributionHistory) {
            let current_count = self.distribution_count.read();
            let current_count = if current_count == 0.into() {
                0.into()
            } else {
                current_count
            };

            self.distribution_history.write(current_count, distribution);
            self.distribution_count.write(current_count + 1);
        }
    }

    #[abi(embed_v0)]
    impl DistributorImpl of IDistributor<ContractState> {
        fn distribute(
            ref self: ContractState,
            amount: u256,
            recipients: Array<ContractAddress>,
            token: ContractAddress,
        ) {
            // Validate inputs
            assert(!recipients.is_empty(), EMPTY_RECIPIENTS);
            assert(amount > 0, ZERO_AMOUNT);
            assert(!token.is_zero(), INVALID_TOKEN);

            // Initialize the dispatcher
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            let caller = get_caller_address();
            let timestamp: u64 = get_block_timestamp();

            // Calculate total amount and check allowance
            let total_amount = amount * recipients.len().into();
            let allowance = token_dispatcher.allowance(caller, get_contract_address());
            assert(allowance >= total_amount, INSUFFICIENT_ALLOWANCE);

            // Update global statistics
            self.update_global_stats(total_amount);
            self.update_token_stats(token, total_amount, recipients.len());
            self.update_user_stats(caller, total_amount, token);

            // Perform distribution
            let recipients_list = recipients.span();
            for recipient in recipients {
                token_dispatcher.transfer_from(caller, recipient, amount);
                self.emit(WeightedDistribution { recipient, amount });
            };

            // Record distribution history
            self
                .record_distribution(
                    DistributionHistory {
                        caller,
                        token,
                        amount: total_amount,
                        recipients_count: recipients_list.len(),
                        timestamp
                    }
                );

            // Emit summary event
            self
                .emit(
                    Event::Distribution(
                        Distribution {
                            caller, token, amount, recipients_count: recipients_list.len(),
                        },
                    ),
                );
        }

        fn distribute_weighted(
            ref self: ContractState,
            amounts: Array<u256>,
            recipients: Array<ContractAddress>,
            token: ContractAddress,
        ) {
            // Validate inputs
            assert(!recipients.is_empty(), EMPTY_RECIPIENTS);
            assert(amounts.len() == recipients.len(), ARRAY_LEN_MISMATCH);

            let caller = get_caller_address();
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            let mut total_amount: u256 = 0;

            // Calculate total amount needed
            let mut i = 0;
            loop {
                if i >= amounts.len() {
                    break;
                }
                let amount = *amounts.at(i);
                assert(amount > 0, ZERO_AMOUNT);
                total_amount += amount;
                i += 1;
            };

            // Transfer tokens from sender to recipients
            i = 0;
            loop {
                if i >= recipients.len() {
                    break;
                }
                let recipient = *recipients.at(i);
                let amount = *amounts.at(i);

                token_dispatcher.transfer_from(caller, recipient, amount);

                // Emit event for each distribution
                self.emit(WeightedDistribution { recipient, amount });

                i += 1;
            };
            // Add summary event at the end
            self
                .emit(
                    Event::Distribution(
                        Distribution {
                            caller, token, amount: total_amount, recipients_count: recipients.len(),
                        },
                    ),
                );
        }

        fn get_balance(self: @ContractState) -> u256 {
            self.balance.read()
        }

        fn get_total_distributions(self: @ContractState) -> u256 {
            self.total_distributions.read()
        }

        fn get_total_distributed_amount(self: @ContractState) -> u256 {
            self.total_distributed_amount.read()
        }

        fn get_token_stats(self: @ContractState, token: ContractAddress) -> TokenStats {
            self.token_stats.read(token)
        }

        fn get_user_stats(self: @ContractState, user: ContractAddress) -> UserStats {
            self.user_stats.read(user)
        }

        fn get_distribution_history(
            self: @ContractState, start_id: u256, limit: u256,
        ) -> Array<DistributionHistory> {
            let mut history: Array<DistributionHistory> = ArrayTrait::new();
            let mut i = start_id;

            while i < start_id + limit {
                let distribution = self.distribution_history.read(i);
                history.append(distribution);
                i += 1;
            };
            history
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

}
