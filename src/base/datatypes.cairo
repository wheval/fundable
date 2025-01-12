use starknet::ContractAddress;

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
    Completed, // Stream has completed its full duration
    Paused, // Stream is temporarily paused
    Voided // Stream has been permanently voided
}
