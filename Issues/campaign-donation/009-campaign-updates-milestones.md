---
title: Add campaign updates and milestone tracking
labels: enhancement, priority-medium, user-experience
assignees: 
---

## Description

Enable campaign owners to post updates and track milestones, similar to how GoFundMe allows campaign creators to keep donors informed about progress and how funds are being used.

## Requirements

### 1. Campaign Updates
```cairo
struct CampaignUpdate {
    update_id: u256,
    campaign_id: u256,
    title: ByteArray,
    content: ByteArray,
    image_url: ByteArray,
    timestamp: u64,
    update_type: UpdateType,
}

enum UpdateType {
    General,
    Milestone,
    Emergency,
    ThankYou,
}
```

### 2. Update Management Functions
```cairo
fn post_campaign_update(
    ref self: ContractState,
    campaign_id: u256,
    title: ByteArray,
    content: ByteArray,
    image_url: ByteArray,
    update_type: UpdateType
) -> u256

fn edit_campaign_update(
    ref self: ContractState,
    campaign_id: u256,
    update_id: u256,
    title: ByteArray,
    content: ByteArray
)

fn delete_campaign_update(
    ref self: ContractState,
    campaign_id: u256,
    update_id: u256
)
```

### 3. Milestone Tracking
```cairo
struct Milestone {
    milestone_id: u256,
    campaign_id: u256,
    title: ByteArray,
    description: ByteArray,
    target_amount: u256,
    achieved: bool,
    achieved_at: u64,
}

fn add_milestone(
    ref self: ContractState,
    campaign_id: u256,
    title: ByteArray,
    description: ByteArray,
    target_amount: u256
) -> u256

fn mark_milestone_achieved(
    ref self: ContractState,
    campaign_id: u256,
    milestone_id: u256
)
```

### 4. Query Functions
```cairo
fn get_campaign_updates(
    self: @ContractState,
    campaign_id: u256,
    pagination: PaginationParams
) -> PaginatedResult<CampaignUpdate>

fn get_campaign_milestones(
    self: @ContractState,
    campaign_id: u256
) -> Array<Milestone>

fn get_latest_update(
    self: @ContractState,
    campaign_id: u256
) -> Option<CampaignUpdate>
```

### 5. Notification System
- Emit UpdatePosted event when new update is posted
- Emit MilestoneAchieved event when milestone is reached
- Consider integration with notification services

## Acceptance Criteria
- [ ] Campaign owners can post updates
- [ ] Updates support different types
- [ ] Updates can be edited/deleted by owner
- [ ] Milestones automatically marked when amount reached
- [ ] Updates are paginated for efficiency
- [ ] Character limits enforced (title: 100, content: 2000)
- [ ] Only campaign owner can manage updates
- [ ] Events emitted for all update actions
- [ ] Tests cover all update scenarios

## Technical Notes
- Consider storing update content on IPFS
- Implement rate limiting for update posting
- Add spam detection for update content
- Cache latest update for quick access

## User Experience
- Show update count on campaign
- Highlight new updates since last visit
- Email notifications for major updates (off-chain)
- Rich text support for updates

## Future Enhancements
- Comment system on updates
- Update reactions/likes
- Video update support
- Donor-only updates 