---
title: Optimize query functions with pagination and filtering
labels: enhancement, performance, priority-high
assignees: 
---

## Description

Current query functions (`get_campaigns`, `get_campaign_donations`) load all data at once, which will cause performance issues and high gas costs as the platform grows. Implement pagination and filtering for efficient data retrieval.

## Requirements

### 1. Pagination Support
```cairo
struct PaginationParams {
    offset: u32,
    limit: u32,
}

struct PaginatedResult<T> {
    items: Array<T>,
    total_count: u256,
    has_next: bool,
}
```

### 2. Update Query Functions
```cairo
fn get_campaigns_paginated(
    self: @ContractState,
    pagination: PaginationParams,
    filter: CampaignFilter
) -> PaginatedResult<Campaigns>

fn get_campaign_donations_paginated(
    self: @ContractState,
    campaign_id: u256,
    pagination: PaginationParams
) -> PaginatedResult<Donations>
```

### 3. Filtering Options
```cairo
struct CampaignFilter {
    owner: Option<ContractAddress>,
    status: Option<CampaignState>,
    category: Option<felt252>,
    asset: Option<felt252>,
    min_target: Option<u256>,
    max_target: Option<u256>,
    created_after: Option<u64>,
    created_before: Option<u64>,
}
```

### 4. Sorting Options
```cairo
enum SortBy {
    CreatedAt,
    TargetAmount,
    CurrentAmount,
    PercentageFunded,
    DonationCount,
}

enum SortOrder {
    Ascending,
    Descending,
}
```

### 5. Indexed Storage
- Add reverse mappings for efficient lookups
- Consider using merkle trees for large datasets
- Implement caching strategies

## Acceptance Criteria
- [ ] Pagination works correctly with limits and offsets
- [ ] Filters correctly narrow results
- [ ] Sorting produces expected order
- [ ] Gas costs remain reasonable for large datasets
- [ ] Edge cases handled (empty results, out of bounds)
- [ ] Backwards compatibility maintained
- [ ] Performance benchmarks show improvement
- [ ] Tests cover pagination edge cases

## Technical Notes
- Consider implementing cursor-based pagination for better performance
- Use storage patterns that support efficient range queries
- Implement result size limits to prevent DoS
- Consider off-chain indexing for complex queries

## Performance Targets
- Query 100 campaigns: < 500k gas
- Query 1000 donations: < 1M gas
- Filter operations: O(1) where possible

## Migration Plan
- Keep old functions for backwards compatibility
- Mark old functions as deprecated
- Provide migration guide for integrators 