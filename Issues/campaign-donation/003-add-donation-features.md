---
title: Enhance donation features with messages and anonymity
labels: enhancement, priority-medium
assignees: 
---

## Description

Improve the donation experience by allowing donors to attach messages and choose to donate anonymously, similar to GoFundMe and other crowdfunding platforms.

## Requirements

### 1. Update Donations Struct
```cairo
struct Donations {
    donation_id: u256,
    donor: ContractAddress,
    campaign_id: u256,
    amount: u256,
    asset: felt252,
    message: ByteArray,        // New: donor message
    is_anonymous: bool,        // New: anonymity flag
    timestamp: u64,            // New: donation timestamp
}
```

### 2. Update `donate_to_campaign` Function
```cairo
fn donate_to_campaign(
    ref self: ContractState,
    campaign_id: u256,
    amount: u256,
    token: ContractAddress,
    message: ByteArray,
    is_anonymous: bool
) -> u256
```

### 3. Add Donation Features
- **Minimum donation amount**: Configurable per campaign or global
- **Donation message**: Optional message (max 280 chars)
- **Anonymous donations**: Hide donor address in public queries
- **Donation updates**: Allow donors to update their message

### 4. New Query Functions
```cairo
fn get_public_donations(self: @ContractState, campaign_id: u256) -> Array<PublicDonation>
fn get_donor_history(self: @ContractState, donor: ContractAddress) -> Array<Donations>
fn get_top_donations(self: @ContractState, campaign_id: u256, limit: u32) -> Array<Donations>
```

### 5. Privacy Considerations
- Anonymous donations should hide donor address in public queries
- Only donor and campaign owner can see full details of anonymous donations
- Implement access control for sensitive queries

## Acceptance Criteria
- [ ] Donations support messages and anonymity
- [ ] Message length validation (max 280 chars)
- [ ] Anonymous donations properly hidden in public queries
- [ ] Minimum donation amount enforced
- [ ] Query functions respect privacy settings
- [ ] Events include new donation fields
- [ ] Tests cover all new features

## Technical Notes
- Consider storing messages off-chain (IPFS) for gas efficiency
- Implement efficient sorting for top donations query
- Use access control modifiers for sensitive data

## UI/UX Considerations
- Default to non-anonymous donations
- Clear indication when donation is anonymous
- Character counter for messages 