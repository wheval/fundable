use starknet::ContractAddress;
use crate::base::types::{DistributionHistory, TokenStats, UserStats};

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
    // Global statistics
    fn get_total_distributions(self: @TContractState) -> u256;
    fn get_total_distributed_amount(self: @TContractState) -> u256;

    // Token-specific statistics
    fn get_token_stats(self: @TContractState, token: ContractAddress) -> TokenStats;

    // User-specific statistics
    fn get_user_stats(self: @TContractState, user: ContractAddress) -> UserStats;

    // Distribution history with pagination
    fn get_distribution_history(
        self: @TContractState, start_id: u256, limit: u256,
    ) -> Array<DistributionHistory>;
}
