---
title: Implement refund mechanism for failed/cancelled campaigns
labels: enhancement, priority-high, security
assignees: 
---

## Description

Currently, there's no way for donors to get their money back if a campaign fails to reach its goal or is cancelled. This is a critical feature for donor trust and platform credibility.

## Requirements

### 1. Add Campaign States
Update campaign to support multiple states:
```cairo
enum CampaignState {
    Active,
    GoalReached,
    Failed,
    Cancelled,
    Withdrawn,
    Refunding
}
```

### 2. Add Deadline Support
- Add `deadline: u64` field to `Campaigns` struct
- Campaigns automatically fail if deadline passes without reaching goal

### 3. Implement Refund Functions
```cairo
fn cancel_campaign(ref self: ContractState, campaign_id: u256)
fn request_refund(ref self: ContractState, campaign_id: u256, donation_id: u256)
fn batch_refund(ref self: ContractState, campaign_id: u256, donation_ids: Array<u256>)
```

### 4. Refund Logic
- Only campaign owner can cancel an active campaign
- Refunds available when campaign is Failed or Cancelled
- Track refund status per donation to prevent double refunds
- Emit RefundProcessed event

### 5. Security Considerations
- Implement reentrancy guards
- Ensure proper state transitions
- Validate refund amounts match original donations

## Acceptance Criteria
- [ ] Campaign states implemented
- [ ] Deadline functionality working
- [ ] Individual refund mechanism tested
- [ ] Batch refund for gas efficiency
- [ ] Cannot refund already refunded donations
- [ ] Cannot refund from successful campaigns
- [ ] Comprehensive test coverage
- [ ] Events emitted for all refund actions

## Technical Notes
- Consider pull vs push pattern for refunds
- Implement circuit breaker for emergency stops
- Gas optimization for batch operations

## Edge Cases
- Campaign reaches goal just before deadline
- Partial refunds if campaign is partially funded
- Handling failed refund transactions 