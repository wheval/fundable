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
