use starknet::ContractAddress;

/// Interface for the distribution contract
#[starknet::interface]
pub trait IDistributor<TContractState> {
    /// Distributes equal amounts of tokens to multiple recipients
    fn distribute(
        ref self: TContractState,
        amount: u256,
        recipients: Array<ContractAddress>,
        token: ContractAddress
    );

    /// Distributes different amounts of tokens to multiple recipients
    fn distribute_weighted(
        ref self: TContractState,
        amounts: Array<u256>,
        recipients: Array<ContractAddress>,
        token: ContractAddress
    );

    /// Gets the current balance of the contract
    fn get_balance(self: @TContractState) -> u256;
}

/// Error messages for the Distributor contract
pub mod Errors {
    pub const EMPTY_RECIPIENTS: felt252 = 'Recipients array is empty';
    pub const ZERO_AMOUNT: felt252 = 'Amount must be greater than 0';
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient allowance';
    pub const INVALID_TOKEN: felt252 = 'Invalid token address';
}

/// Main contract implementation
#[starknet::contract]
mod Distributor {
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address, ClassHash};
    use core::num::traits::Zero;
    use super::Errors;

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

    #[derive(Drop, starknet::Event)]
    struct Distribution {
        #[key]
        caller: ContractAddress,
        token: ContractAddress,
        amount: u256,
        recipients_count: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct WeightedDistribution {
        recipient: ContractAddress,
        amount: u256,
    }

    #[abi(embed_v0)]
    impl DistributorImpl of super::IDistributor<ContractState> {
        fn distribute(
            ref self: ContractState,
            amount: u256,
            recipients: Array<ContractAddress>,
            token: ContractAddress,
        ) {
            // Validate inputs
            assert(!recipients.is_empty(), Errors::EMPTY_RECIPIENTS);
            assert(amount > 0, Errors::ZERO_AMOUNT);
            assert(!token.is_zero(), Errors::INVALID_TOKEN);

            // Create ERC20 dispatcher to interact with the token contract
            let token_dispatcher = IERC20Dispatcher { contract_address: token };

            // Transfer tokens to each recipient
            let caller = get_caller_address();

            // Check allowance
            let total_amount = amount * recipients.len().into();
            let allowance = token_dispatcher.allowance(caller, get_contract_address());
            assert(allowance >= total_amount, Errors::INSUFFICIENT_ALLOWANCE);

            let recipients_list = recipients.span();

            // Distribute tokens and emit event for each transfer
            for recipient in recipients {
                token_dispatcher.transfer_from(caller, recipient, amount);
                self.emit(WeightedDistribution { recipient, amount });
            };

            // Emit summary event
            self.emit(
                Event::Distribution(
                    Distribution { 
                        caller,
                        token, 
                        amount, 
                        recipients_count: recipients_list.len() 
                    }
                )
            );
        }

        fn distribute_weighted(
            ref self: ContractState,
            amounts: Array<u256>,
            recipients: Array<ContractAddress>,
            token: ContractAddress,
        ) {
            // Validate inputs
            assert(!recipients.is_empty(), 'Recipients array is empty');
            assert(amounts.len() == recipients.len(), 'Arrays length mismatch');

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
                assert(amount > 0, 'Amount must be greater than 0');
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
            self.emit(
                Event::Distribution(
                    Distribution { 
                        caller,
                        token, 
                        amount: total_amount, 
                        recipients_count: recipients.len() 
                    }
                )
            );
        }

        fn get_balance(self: @ContractState) -> u256 {
            self.balance.read()
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
