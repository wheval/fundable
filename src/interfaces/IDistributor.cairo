use starknet::ContractAddress;
use crate::base::types::{DistributionHistory, TokenStats, UserStats};

/// Interface for the distribution contract
#[starknet::interface]
pub trait IDistributor<TContractState> {
    /// @notice Validates the ERC20 token to ensure it is a valid token for distribution
    /// @param token The ERC20 token address to be validated
    /// @dev This function checks whether the provided token address is non-zero and verifies that
    /// the token has a valid decimal value.
    /// If the token is invalid (either a zero address or a token with zero decimals), an assertion
    /// is triggered, preventing further operations.
    fn validate_token(self: @TContractState, token: ContractAddress);

    /// @notice Distributes equal amounts of tokens to multiple recipients
    /// @param amount The total amount to distribute
    /// @param recipients Array of recipient addresses
    /// @param token The ERC20 token to distribute
    fn distribute(
        ref self: TContractState,
        amount: u256,
        recipients: Array<ContractAddress>,
        token: ContractAddress,
    );

    /// @notice Distributes tokens to recipients with custom amounts
    /// @param amounts Array of amounts to distribute to each recipient
    /// @param recipients Array of recipient addresses
    /// @param token The ERC20 token to distribute
    fn distribute_weighted(
        ref self: TContractState,
        amounts: Array<u256>,
        recipients: Array<ContractAddress>,
        token: ContractAddress,
    );

    /// @notice Gets the current protocol fee percentage
    /// @return The protocol fee percentage (100 = 1%)
    fn get_protocol_fee_percent(self: @TContractState) -> u256;

    /// @notice Sets a new protocol fee percentage
    /// @param new_fee_percent The new fee percentage to set (100 = 1%)
    fn set_protocol_fee_percent(ref self: TContractState, new_fee_percent: u256);

    /// @notice Gets the current protocol fee collection address
    /// @return The address where protocol fees are sent
    fn get_protocol_fee_address(self: @TContractState) -> ContractAddress;

    /// @notice Sets a new protocol fee collection address
    /// @param new_fee_address The new address to collect protocol fees
    fn set_protocol_fee_address(ref self: TContractState, new_fee_address: ContractAddress);

    /// @notice Gets the current balance of the contract
    /// @return The current balance
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
