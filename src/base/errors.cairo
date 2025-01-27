/// Error messages for the Distributor contract
pub mod Errors {
    pub const EMPTY_RECIPIENTS: felt252 = 'Error: Recipients array empty.';
    pub const INVALID_RECIPIENT: felt252 = 'Error: Invalid recipient.';
    pub const WRONG_RECIPIENT: felt252 = 'Error: Not stream recipient.';
    pub const WRONG_SENDER: felt252 = 'Error: Not stream sender.';
    pub const ZERO_AMOUNT: felt252 = 'Error: Amount must be > 0.';
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Error: Insufficient allowance.';
    pub const INVALID_TOKEN: felt252 = 'Error: Invalid token address.';
    pub const ARRAY_LEN_MISMATCH: felt252 = 'Error: Arrays length mismatch.';
    pub const UNEXISTING_STREAM: felt252 = 'Error: Stream does not exist.';
    pub const END_BEFORE_START: felt252 = 'Error: End time < start time.';
}
