use starknet::ContractAddress;

/// @title PaymentStream Events
/// @notice Contains all events emitted by the PaymentStream contract for tracking stream lifecycle
/// @dev All events use stream_id as an indexed key parameter for efficient filtering

#[event]
#[derive(Drop, starknet::Event)]
enum Event {
    StreamCreated: StreamCreated,
    StreamWithdrawn: StreamWithdrawn,
    StreamCanceled: StreamCanceled,
    StreamPaused: StreamPaused,
    StreamRestarted: StreamRestarted,
    StreamVoided: StreamVoided
}

/// @notice Emitted when a new payment stream is created
/// @dev Emitted by create_stream() function
/// @param stream_id Unique identifier for the stream
/// @param sender Address that created and funded the stream
/// @param recipient Address that will receive the streamed payments
/// @param total_amount Total amount of tokens to be streamed
/// @param token Address of the ERC20 token being streamed
#[derive(Drop, starknet::Event)]
struct StreamCreated {
    #[key]
    stream_id: u256,
    sender: ContractAddress,
    recipient: ContractAddress,
    total_amount: u256,
    token: ContractAddress
}

/// @notice Emitted when tokens are withdrawn from a stream
/// @dev Emitted by withdraw() and withdraw_max() functions
/// @param stream_id Unique identifier for the stream
/// @param recipient Address that received the withdrawn tokens
/// @param amount Amount of tokens withdrawn
/// @param protocol_fee Amount of tokens taken as protocol fee
#[derive(Drop, starknet::Event)]
struct StreamWithdrawn {
    #[key]
    stream_id: u256,
    recipient: ContractAddress,
    amount: u256,
    protocol_fee: u128
}

/// @notice Emitted when a stream is canceled by an authorized user
/// @dev Emitted by cancel() function
/// @param stream_id Unique identifier for the canceled stream
/// @param remaining_balance Amount of tokens returned to sender
#[derive(Drop, starknet::Event)]
struct StreamCanceled {
    #[key]
    stream_id: u256,
    remaining_balance: u256,
}

/// @notice Emitted when a stream is paused by an authorized user
/// @dev Emitted by pause_stream() function
/// @param stream_id Unique identifier for the paused stream
/// @param paused_at Unix timestamp when the stream was paused
#[derive(Drop, starknet::Event)]
struct StreamPaused {
    #[key]
    stream_id: u256,
    paused_at: u64,
}

/// @notice Emitted when a paused stream is restarted
/// @dev Emitted by restart_stream() function
/// @param stream_id Unique identifier for the restarted stream
/// @param restarted_at Unix timestamp when the stream was restarted
#[derive(Drop, starknet::Event)]
struct StreamRestarted {
    #[key]
    stream_id: u256,
    restarted_at: u64,
}

/// @notice Emitted when a stream is permanently voided
/// @dev Emitted by void_stream() function
/// @param stream_id Unique identifier for the voided stream
/// @param void_reason Numeric code indicating the reason for voiding
#[derive(Drop, starknet::Event)]
struct StreamVoided {
    #[key]
    stream_id: u256,
    void_reason: u8,
} 