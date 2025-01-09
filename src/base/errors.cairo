/// Error messages for the Distributor contract
pub mod Errors {
    pub const EMPTY_RECIPIENTS: felt252 = 'Recipients array is empty';
    pub const ZERO_AMOUNT: felt252 = 'Amount must be greater than 0';
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient allowance';
    pub const INVALID_TOKEN: felt252 = 'Invalid token address';
}
