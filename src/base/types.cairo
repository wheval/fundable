use starknet::ContractAddress;
use core::serde::Serde;
use core::option::OptionTrait;

/// @notice Struct containing all data for a single stream
#[derive(Drop, Serde, starknet::Store)]
pub struct Stream {
    pub sender: ContractAddress,
    pub recipient: ContractAddress,
    pub total_amount: u256,
    pub withdrawn_amount: u256,
    pub start_time: u64,
    pub end_time: u64,
    pub cancelable: bool,
    pub token: ContractAddress,
    pub status: StreamStatus,
    pub rate_per_second: u256,
    pub last_update_time: u64,
}

#[derive(Drop, starknet::Event)]
pub struct Distribution {
    #[key]
    pub caller: ContractAddress,
    pub token: ContractAddress,
    pub amount: u256,
    pub recipients_count: u32,
}

#[derive(Drop, starknet::Event)]
pub struct WeightedDistribution {
    pub recipient: ContractAddress,
    pub amount: u256,
}

/// @notice Enum representing the possible states of a stream
#[derive(Drop, Serde, starknet::Store)]
pub enum StreamStatus {
    Active, // Stream is actively streaming tokens
    Canceled, // Stream has been canceled by the sender
    Completed, // Stream has completed its full duration smart 
    Paused, // Stream is temporarily paused
    Voided // Stream has been permanently voided
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TokenStats {
    pub total_amount: u256, // Total amount distributed for this token
    pub distribution_count: u256, // Number of distributions involving this token
    pub last_distribution_time: u64, // Timestamp of the last distribution for this token
    pub unique_recipients: u256, // Count of unique recipients
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct UserStats {
    pub distributions_initiated: u256, // Number of distributions initiated by the user
    pub total_amount_distributed: u256, // Total amount distributed by the user
    pub last_distribution_time: u64, // Timestamp of the last distribution by the user
    pub unique_tokens_used: u256, // Count of unique tokens used by the user
}

#[derive(Drop, Serde, starknet::Store)]
pub struct DistributionHistory {
    #[key]
    pub caller: ContractAddress,
    pub token: ContractAddress,
    pub amount: u256,
    pub recipients_count: u32,
    pub timestamp: u64,
}
