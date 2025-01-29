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
pub struct StreamMetrics {
    last_activity: u64,
    total_withdrawn: u256,
    withdrawal_count: u32,
    pause_count: u32,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ProtocolMetrics {
    pub total_active_streams: u256,
    pub total_tokens_distributed: u256,
    pub total_streams_created: u256,
}
