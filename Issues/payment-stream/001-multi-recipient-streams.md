---
title: Implement multi-recipient streaming (splits and distributions)
labels: enhancement, priority-high, feature
assignees: 
---

## Description

Currently, streams can only have one recipient. Modern payment streaming platforms like Superfluid and 0xSplits support streaming to multiple recipients with configurable splits. This is essential for team payments, revenue sharing, and automated distributions.

## Requirements

### 1. Multi-Recipient Stream Structure
```cairo
struct MultiStream {
    stream_id: u256,
    sender: ContractAddress,
    recipients: Array<Recipient>,
    total_amount: u256,
    token: ContractAddress,
    duration: u64,
    split_type: SplitType,
}

struct Recipient {
    address: ContractAddress,
    percentage: u16,        // Basis points (10000 = 100%)
    fixed_amount: u256,     // For fixed splits
    min_amount: u256,       // Minimum guaranteed amount
}

enum SplitType {
    Percentage,      // Split by percentage
    Fixed,          // Fixed amounts per recipient
    Weighted,       // Weighted distribution
    Priority,       // Priority-based (waterfall)
}
```

### 2. Creation Functions
```cairo
fn create_multi_stream(
    ref self: ContractState,
    recipients: Array<Recipient>,
    total_amount: u256,
    duration: u64,
    token: ContractAddress,
    split_type: SplitType,
    cancelable: bool
) -> u256

fn create_split_stream(
    ref self: ContractState,
    recipients: Array<(ContractAddress, u16)>, // (address, percentage)
    total_amount: u256,
    duration: u64,
    token: ContractAddress
) -> u256
```

### 3. Management Functions
```cairo
fn update_split_percentages(
    ref self: ContractState,
    stream_id: u256,
    new_percentages: Array<(ContractAddress, u16)>
)

fn add_recipient(
    ref self: ContractState,
    stream_id: u256,
    recipient: Recipient
)

fn remove_recipient(
    ref self: ContractState,
    stream_id: u256,
    recipient: ContractAddress
)
```

### 4. Withdrawal Logic
- Each recipient can withdraw their portion independently
- Support batch withdrawals for gas efficiency
- Handle rounding errors in splits
- Ensure no funds are locked due to precision loss

### 5. Advanced Features
- **Nested splits**: Recipients can be other split contracts
- **Dynamic rebalancing**: Adjust splits based on conditions
- **Minimum thresholds**: Only distribute if above threshold
- **Vesting schedules**: Different vesting per recipient

## Acceptance Criteria
- [ ] Multi-recipient streams created successfully
- [ ] Percentages always sum to 100%
- [ ] Each recipient can withdraw independently
- [ ] No funds locked due to rounding
- [ ] Gas-efficient batch operations
- [ ] Support for at least 10 recipients per stream
- [ ] Events emitted for all split operations
- [ ] Comprehensive test coverage

## Technical Notes
- Use fixed-point arithmetic for precise splits
- Consider using a factory pattern for split contracts
- Implement efficient storage for large recipient lists
- Handle edge cases like recipient removal mid-stream

## Use Cases
- Team salary distributions
- Revenue sharing agreements
- DAO treasury management
- Automated profit distribution
- Commission splits

## References
- [0xSplits Documentation](https://docs.0xsplits.xyz/)
- [Superfluid Distributions](https://docs.superfluid.finance/) 