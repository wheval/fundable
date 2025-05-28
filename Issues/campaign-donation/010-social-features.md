---
title: Add social features and donor recognition system
labels: enhancement, priority-low, user-engagement
assignees: 
---

## Description

Implement social features to increase engagement and donor recognition, similar to GoFundMe's social sharing and donor wall features.

## Requirements

### 1. Donor Recognition Levels
```cairo
enum DonorTier {
    Bronze,    // < $50
    Silver,    // $50 - $250
    Gold,      // $250 - $1000
    Platinum,  // $1000 - $5000
    Diamond,   // > $5000
}

struct DonorProfile {
    total_donated: u256,
    campaign_count: u32,
    first_donation: u64,
    tier: DonorTier,
    badges: Array<Badge>,
}
```

### 2. Social Sharing Features
```cairo
struct ShareableLink {
    campaign_id: u256,
    referrer: ContractAddress,
    share_code: felt252,
    clicks: u32,
    donations_generated: u256,
}

fn create_shareable_link(
    ref self: ContractState,
    campaign_id: u256
) -> felt252

fn track_referral_donation(
    ref self: ContractState,
    campaign_id: u256,
    share_code: felt252,
    donation_id: u256
)
```

### 3. Donor Wall & Leaderboards
```cairo
fn get_top_donors_global(
    self: @ContractState,
    limit: u32,
    timeframe: Timeframe
) -> Array<DonorLeaderboardEntry>

fn get_campaign_donor_wall(
    self: @ContractState,
    campaign_id: u256,
    tier_filter: Option<DonorTier>
) -> Array<DonorWallEntry>

struct DonorWallEntry {
    donor: ContractAddress,
    display_name: ByteArray,
    amount: u256,
    message: ByteArray,
    tier: DonorTier,
    is_anonymous: bool,
}
```

### 4. Achievement System
```cairo
enum Badge {
    FirstDonation,
    ConsistentGiver,    // Donated to 5+ campaigns
    EarlySupporter,     // Donated in first 24h
    GoalMaker,          // Donation pushed campaign over goal
    Philanthropist,     // Total donations > $10k
    Advocate,           // Shared campaigns that raised $1k+
}

fn award_badge(
    ref self: ContractState,
    donor: ContractAddress,
    badge: Badge
)

fn get_donor_badges(
    self: @ContractState,
    donor: ContractAddress
) -> Array<Badge>
```

### 5. Social Interactions
```cairo
fn thank_donor(
    ref self: ContractState,
    campaign_id: u256,
    donation_id: u256,
    message: ByteArray
)

fn highlight_donation(
    ref self: ContractState,
    campaign_id: u256,
    donation_id: u256
)
```

## Acceptance Criteria
- [ ] Donor tiers calculated automatically
- [ ] Shareable links track referrals
- [ ] Leaderboards update in real-time
- [ ] Badges awarded automatically
- [ ] Anonymous donors excluded from public displays
- [ ] Thank you messages delivered to donors
- [ ] Social features respect privacy settings
- [ ] Performance optimized for large datasets

## Technical Notes
- Cache leaderboard data for performance
- Use merkle trees for efficient badge verification
- Implement rate limiting on social actions
- Consider off-chain storage for social data

## Privacy Considerations
- Allow donors to opt-out of leaderboards
- Respect anonymous donation settings
- Provide granular privacy controls
- GDPR compliance for profile data

## Gamification Elements
- Streak tracking for regular donors
- Seasonal badges and campaigns
- Matching challenges
- Community goals

## Future Enhancements
- Integration with social media APIs
- NFT badges for achievements
- Donor communities/forums
- Impact reporting dashboard 