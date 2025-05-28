---
title: Implement batch operations and gas optimizations
labels: enhancement, performance, priority-high
assignees: 
---

## Description

Add batch operations for creating, managing, and withdrawing from multiple streams in a single transaction. This significantly reduces gas costs and improves UX for users managing multiple streams, following patterns from Sablier V2 and disperse.app.

## Requirements

### 1. Batch Stream Creation
```cairo
struct BatchStreamParams {
    recipient: ContractAddress,
    total_amount: u256,
    duration: u64,
    cancelable: bool,
    transferable: bool,
}

fn create_batch_streams(
    ref self: ContractState,
    params: Array<BatchStreamParams>,
    token: ContractAddress
) -> Array<u256>  // Returns array of stream IDs

fn create_identical_streams(
    ref self: ContractState,
    recipients: Array<ContractAddress>,
    amount_per_recipient: u256,
    duration: u64,
    token: ContractAddress
) -> Array<u256>

fn create_proportional_streams(
    ref self: ContractState,
    recipients: Array<(ContractAddress, u16)>,  // (address, percentage)
    total_amount: u256,
    duration: u64,
    token: ContractAddress
) -> Array<u256>
```

### 2. Batch Management
```cairo
fn batch_pause_streams(
    ref self: ContractState,
    stream_ids: Array<u256>
) -> Array<bool>

fn batch_cancel_streams(
    ref self: ContractState,
    stream_ids: Array<u256>
) -> Array<bool>

fn batch_update_recipients(
    ref self: ContractState,
    updates: Array<(u256, ContractAddress)>  // (stream_id, new_recipient)
) -> Array<bool>

fn batch_deposit(
    ref self: ContractState,
    deposits: Array<(u256, u256)>  // (stream_id, amount)
) -> bool
```

### 3. Batch Withdrawals
```cairo
fn batch_withdraw(
    ref self: ContractState,
    stream_ids: Array<u256>
) -> Array<(u256, u256)>  // Returns (withdrawn_amount, fee) per stream

fn batch_withdraw_to(
    ref self: ContractState,
    withdrawals: Array<(u256, ContractAddress, u256)>  // (stream_id, recipient, amount)
) -> Array<bool>

fn withdraw_multiple_for_recipient(
    ref self: ContractState,
    recipient: ContractAddress,
    stream_ids: Array<u256>
) -> u256  // Total withdrawn
```

### 4. Batch Queries
```cairo
fn batch_get_withdrawable(
    self: @ContractState,
    stream_ids: Array<u256>
) -> Array<u256>

fn batch_get_stream_info(
    self: @ContractState,
    stream_ids: Array<u256>
) -> Array<StreamInfo>

struct StreamInfo {
    stream_id: u256,
    recipient: ContractAddress,
    balance: u256,
    withdrawable: u256,
    status: StreamStatus,
    end_time: u64,
}

fn get_all_streams_for_user(
    self: @ContractState,
    user: ContractAddress,
    role: UserRole  // Sender or Recipient
) -> Array<u256>
```

### 5. Gas Optimizations
```cairo
// Packed storage for batch operations
struct PackedStreamData {
    // Pack multiple values into single storage slot
    recipient_and_status: felt252,  // Address + status in one slot
    amounts: u256,                   // total_amount << 128 | withdrawn_amount
    timestamps: u256,                // start_time << 128 | duration
}

// Merkle tree for batch claims
struct MerkleBatchClaim {
    merkle_root: felt252,
    total_amount: u256,
    token: ContractAddress,
    expiry: u64,
}

fn create_merkle_batch(
    ref self: ContractState,
    recipients: Array<(ContractAddress, u256)>,
    token: ContractAddress
) -> felt252  // Returns merkle root

fn claim_from_merkle_batch(
    ref self: ContractState,
    proof: Array<felt252>,
    recipient: ContractAddress,
    amount: u256
)
```

### 6. Multicall Pattern
```cairo
struct Call {
    target: ContractAddress,
    selector: felt252,
    calldata: Array<felt252>,
}

fn multicall(
    ref self: ContractState,
    calls: Array<Call>
) -> Array<Array<felt252>>

fn aggregate_calls(
    ref self: ContractState,
    calls: Array<Call>,
    require_success: bool
) -> (u256, Array<Array<felt252>>)  // (block_number, results)
```

## Acceptance Criteria
- [ ] Batch creation works for 100+ streams
- [ ] Gas savings of >50% vs individual operations
- [ ] Batch operations atomic (all succeed or all fail)
- [ ] Efficient storage packing implemented
- [ ] Merkle claims functional
- [ ] Query operations optimized
- [ ] No timeout issues with large batches
- [ ] Comprehensive test coverage

## Technical Notes
- Implement storage packing for gas efficiency
- Use events efficiently for batch operations
- Consider implementing pagination for very large batches
- Optimize loops to prevent gas limit issues
- Implement circuit breakers for batch size limits

## Performance Targets
- Create 100 streams: < 2M gas
- Batch withdraw 50 streams: < 1M gas
- Query 200 streams: < 500k gas

## Use Cases
- **Payroll**: Pay entire team in one transaction
- **Airdrops**: Distribute tokens to many recipients
- **Vesting**: Set up vesting for all employees
- **Rewards**: Distribute rewards to multiple users
- **Migration**: Move multiple streams between protocols

## Security Considerations
- Prevent DoS through extremely large batches
- Ensure atomic execution
- Validate all inputs in batch
- Handle partial failures gracefully
- Implement reentrancy protection

## References
- [Sablier V2 Batch](https://docs.sablier.com/contracts/v2/guides/batch-create-streams)
- [Disperse.app](https://disperse.app/)
- [Multicall3](https://www.multicall3.com/) 