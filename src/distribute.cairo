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

    /// Gets the current balance of the contract
    fn get_balance(self: @TContractState) -> felt252;
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
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};
    use core::num::traits::Zero;
    use super::Errors;

    #[storage]
    struct Storage {
        balance: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Distribution: Distribution,
    }

    #[derive(Drop, starknet::Event)]
    struct Distribution {
        token: ContractAddress,
        amount: u256,
        recipients_count: u32,
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

            // Distribute tokens
            for recipient in recipients {
                token_dispatcher.transfer_from(caller, recipient, amount);
            };

            // Emit event
            self
                .emit(
                    Event::Distribution(
                        Distribution { token, amount, recipients_count: recipients_list.len() }
                    )
                );
        }

        fn get_balance(self: @ContractState) -> felt252 {
            self.balance.read()
        }
    }
}
