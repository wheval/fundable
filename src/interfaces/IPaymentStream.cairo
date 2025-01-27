use starknet::ContractAddress;
use crate::base::types::Stream;

/// @title IPaymentStream
/// @notice Creates and manages payment streams with linear streaming functions.
#[starknet::interface]
pub trait IPaymentStream<TContractState> {
    /// @notice Creates a new stream by setting the start time and wrapping it in an NFT.
    /// @param recipient The address receiving the tokens
    /// @param total_amount The total amount to be streamed
    /// @param start_time The timestamp when the stream starts
    /// @param end_time The timestamp when the stream ends
    /// @param cancelable Boolean indicating if the stream can be canceled
    /// @param token The contract address of the ERC-20 token to be streamed
    /// @return The ID of the newly created stream
    fn create_stream(
        ref self: TContractState,
        recipient: ContractAddress,
        total_amount: u256,
        start_time: u64,
        end_time: u64,
        cancelable: bool,
        token: ContractAddress,
    ) -> u256;

    /// @notice Withdraws the provided amount minus the protocol fee to the provided address
    /// @param stream_id The ID of the stream to withdraw from
    /// @param amount The amount to withdraw
    /// @param to The address receiving the withdrawn tokens
    /// @return A tuple of (withdrawn_amount, protocol_fee_amount)
    fn withdraw(
        ref self: TContractState, stream_id: u256, amount: u256, to: ContractAddress
    ) -> (u128, u128);

    /// @notice Withdraws the entire withdrawable amount minus the protocol fee
    /// @param stream_id The ID of the stream to withdraw from
    /// @param to The address receiving the withdrawn tokens
    /// @return A tuple of (withdrawn_amount, protocol_fee_amount)
    fn withdraw_max(ref self: TContractState, stream_id: u256, to: ContractAddress) -> (u128, u128);

    /// @notice Cancels the stream
    /// @param stream_id The ID of the stream to cancel
    fn cancel(ref self: TContractState, stream_id: u256);

    /// @notice Pauses the stream
    /// @param stream_id The ID of the stream to pause
    fn pause(ref self: TContractState, stream_id: u256);

    /// @notice Restarts the stream with the provided rate per second
    /// @param stream_id The ID of the stream to restart
    /// @param rate_per_second The amount by which the debt increases every second
    fn restart(ref self: TContractState, stream_id: u256, rate_per_second: u256);

    /// @notice Voids a stream, making it permanently inactive
    /// @param stream_id The ID of the stream to void
    fn void(ref self: TContractState, stream_id: u256);

    /// @notice Returns the stream data for the given ID
    /// @param stream_id The stream ID for the query
    /// @return The Stream struct containing all stream data
    fn get_stream(self: @TContractState, stream_id: u256) -> Stream;

    /// @notice Calculates the amount that the recipient can withdraw
    /// @param stream_id The stream ID for the query
    /// @return The amount that can be withdrawn
    fn get_withdrawable_amount(self: @TContractState, stream_id: u256) -> u256;

    /// @notice Returns whether the stream is currently active
    /// @param stream_id The stream ID for the query
    /// @return Boolean indicating if the stream is active
    fn is_stream_active(self: @TContractState, stream_id: u256) -> bool;

    /// @notice Returns the time at which the total debt exceeds stream balance
    /// @param stream_id The stream ID for the query
    /// @return The timestamp when the stream will be depleted
    fn get_depletion_time(self: @TContractState, stream_id: u256) -> u64;

    /// @notice Returns the total amount owed by the sender to the recipient
    /// @param stream_id The stream ID for the query
    /// @return The total debt amount
    fn get_total_debt(self: @TContractState, stream_id: u256) -> u256;

    /// @notice Returns the amount of debt not covered by the stream balance
    /// @param stream_id The stream ID for the query
    /// @return The uncovered debt amount
    fn get_uncovered_debt(self: @TContractState, stream_id: u256) -> u256;

    /// @notice Returns the amount of debt covered by the stream balance
    /// @param stream_id The stream ID for the query
    /// @return The covered debt amount
    fn get_covered_debt(self: @TContractState, stream_id: u256) -> u256;

    /// @notice Returns the amount that the sender can be refunded
    /// @param stream_id The stream ID for the query
    /// @return The refundable amount
    fn get_refundable_amount(self: @TContractState, stream_id: u256) -> u256;
}
