---
title: Add flexible funding options (all-or-nothing vs keep-it-all)
labels: enhancement, priority-medium
assignees: 
---

## Description

Currently, campaigns can only withdraw funds if they reach their target (all-or-nothing). Many platforms offer flexible funding where campaign owners can withdraw whatever amount is raised, regardless of reaching the goal.

## Requirements

### 1. Add Funding Type to Campaign
```cairo
enum FundingType {
    AllOrNothing,    // Must reach goal to withdraw (current behavior)
    KeepItAll,       // Can withdraw any amount raised
}

struct Campaigns {
    // ... existing fields ...
    funding_type: FundingType,
    allow_over_funding: bool,  // Continue accepting after goal reached
}
```

### 2. Update Campaign Creation
```cairo
fn create_campaign(
    ref self: ContractState,
    campaign_ref: felt252,
    target_amount: u256,
    asset: felt252,
    funding_type: FundingType,
    allow_over_funding: bool,
    // ... other params ...
) -> u256
```

### 3. Modify Withdrawal Logic
- **All-or-nothing**: Current behavior (only withdraw if goal reached)
- **Keep-it-all**: Can withdraw at any time after minimum threshold
- Add minimum withdrawal amount to prevent spam
- Support partial withdrawals for keep-it-all campaigns

### 4. New Withdrawal Functions
```cairo
fn withdraw_partial(ref self: ContractState, campaign_id: u256, amount: u256)
fn get_withdrawable_amount(self: @ContractState, campaign_id: u256) -> u256
fn emergency_withdraw(ref self: ContractState, campaign_id: u256) // After deadline
```

### 5. Donor Protection
- Clear indication of funding type before donation
- Different refund policies based on funding type
- Transparency in campaign progress and withdrawals

## Acceptance Criteria
- [ ] Both funding types implemented and tested
- [ ] Campaigns clearly indicate their funding type
- [ ] Withdrawal logic respects funding type
- [ ] Over-funding option works correctly
- [ ] Partial withdrawals tracked properly
- [ ] Events distinguish between withdrawal types
- [ ] Cannot change funding type after creation
- [ ] Tests cover all funding scenarios

## Technical Notes
- Track withdrawal history for transparency
- Consider time-locks for keep-it-all withdrawals
- Implement withdrawal limits to prevent abuse

## User Experience
- Default to all-or-nothing for donor confidence
- Clear visual indicators for funding type
- Show withdrawal history for transparency 