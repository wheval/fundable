---
title: Add campaign metadata (title, description, image, category)
labels: enhancement, priority-high
assignees: 
---

## Description

Currently, campaigns only store basic financial information (target amount, current amount, asset). To improve user experience and campaign discoverability, we need to add comprehensive metadata support similar to platforms like GoFundMe.

## Requirements

### 1. Update Campaign Struct
Add the following fields to the `Campaigns` struct:
- `title: ByteArray` - Campaign title (max 100 chars)
- `description: ByteArray` - Campaign description (max 1000 chars)
- `image_url: ByteArray` - URL to campaign image
- `category: felt252` - Campaign category (e.g., 'medical', 'education', 'emergency')
- `created_at: u64` - Timestamp of campaign creation
- `updated_at: u64` - Timestamp of last update

### 2. Update `create_campaign` Function
Modify the function signature to accept metadata:
```cairo
fn create_campaign(
    ref self: ContractState,
    campaign_ref: felt252,
    target_amount: u256,
    asset: felt252,
    title: ByteArray,
    description: ByteArray,
    image_url: ByteArray,
    category: felt252
) -> u256
```

### 3. Add Validation
- Title: Required, 1-100 characters
- Description: Required, 1-1000 characters
- Image URL: Optional, valid URL format
- Category: Must be from predefined list

### 4. Add Getter Functions
```cairo
fn get_campaign_metadata(self: @ContractState, campaign_id: u256) -> CampaignMetadata
```

### 5. Update Events
Include metadata in the `Campaign` event emission.

## Acceptance Criteria
- [ ] Campaign struct updated with metadata fields
- [ ] create_campaign accepts and validates metadata
- [ ] Metadata is stored and retrievable
- [ ] Events include metadata information
- [ ] Tests cover all metadata operations
- [ ] Gas optimization considered for storage

## Technical Notes
- Consider using storage packing for metadata fields
- Implement character limit validation
- Consider IPFS for storing larger content

## References
- [StarkNet by Example - Storage Optimization](https://starknet-by-example.voyager.online/advanced-concepts/optimisations/store_using_packing) 