---
title: Add recurring and auto-renewable streams
labels: enhancement, priority-high, feature
assignees: 
---

## Description

Implement recurring payment streams that automatically renew, similar to Superfluid's continuous flows and LlamaPay's recurring payments. This is essential for subscriptions, salaries, and ongoing service payments.

## Requirements

### 1. Recurring Stream Structure
```cairo
struct RecurringStream {
    stream_id: u256,
    base_stream: Stream,
    recurrence_config: RecurrenceConfig,
    renewal_count: u32,
    next_renewal: u64,
    total_renewed_amount: u256,
}

struct RecurrenceConfig {
    interval: u64,              // Time between renewals
    max_renewals: u32,          // 0 for infinite
    auto_renew: bool,
    renewal_amount: u256,       // Amount per period
    increase_rate: u16,         // Percentage increase per renewal
    notice_period: u64,         // Cancellation notice required
    grace_period: u64,          // Payment grace period
}
```

### 2. Creation Functions
```cairo
fn create_recurring_stream(
    ref self: ContractState,
    recipient: ContractAddress,
    amount_per_period: u256,
    interval: u64,
    token: ContractAddress,
    config: RecurrenceConfig
) -> u256

fn create_perpetual_stream(
    ref self: ContractState,
    recipient: ContractAddress,
    flow_rate: u256,  // Tokens per second
    token: ContractAddress,
    buffer_amount: u256  // Security deposit
) -> u256
```

### 3. Renewal Management
```cairo
fn renew_stream(
    ref self: ContractState,
    stream_id: u256
) -> bool

fn batch_renew_streams(
    ref self: ContractState,
    stream_ids: Array<u256>
) -> Array<bool>

fn schedule_renewal(
    ref self: ContractState,
    stream_id: u256,
    renewal_time: u64
)

fn cancel_renewal(
    ref self: ContractState,
    stream_id: u256,
    effective_date: u64
)
```

### 4. Auto-Renewal Logic
```cairo
fn process_auto_renewals(
    ref self: ContractState
) -> Array<u256>  // Returns renewed stream IDs

fn is_renewal_due(
    self: @ContractState,
    stream_id: u256
) -> bool

fn get_renewal_cost(
    self: @ContractState,
    stream_id: u256
) -> u256

fn fund_renewals(
    ref self: ContractState,
    stream_id: u256,
    periods: u32
)
```

### 5. Subscription Features
```cairo
struct SubscriptionTier {
    tier_id: u256,
    name: ByteArray,
    price_per_period: u256,
    features: Array<felt252>,
    max_users: u32,
}

fn upgrade_subscription(
    ref self: ContractState,
    stream_id: u256,
    new_tier: u256
)

fn pause_subscription(
    ref self: ContractState,
    stream_id: u256,
    resume_date: Option<u64>
)

fn apply_discount(
    ref self: ContractState,
    stream_id: u256,
    discount_percentage: u16,
    duration: u32  // Number of periods
)
```

### 6. Payment Management
```cairo
fn get_next_payment_date(
    self: @ContractState,
    stream_id: u256
) -> u64

fn get_payment_history(
    self: @ContractState,
    stream_id: u256
) -> Array<Payment>

struct Payment {
    payment_id: u256,
    amount: u256,
    timestamp: u64,
    period_start: u64,
    period_end: u64,
    status: PaymentStatus,
}

enum PaymentStatus {
    Pending,
    Completed,
    Failed,
    Refunded,
}
```

## Acceptance Criteria
- [ ] Recurring streams auto-renew correctly
- [ ] Renewal notifications work properly
- [ ] Grace periods prevent immediate cancellation
- [ ] Subscription upgrades/downgrades handled
- [ ] Payment history tracked accurately
- [ ] Gas-efficient batch renewals
- [ ] Proper handling of failed renewals
- [ ] Comprehensive test coverage

## Technical Notes
- Implement keeper/bot infrastructure for auto-renewals
- Use efficient storage for recurring metadata
- Handle edge cases like insufficient balance
- Consider implementing payment retries
- Optimize for gas when processing multiple renewals

## Use Cases
- **SaaS Subscriptions**: Monthly/annual software licenses
- **Salaries**: Automated payroll processing
- **Rent**: Recurring property payments
- **Memberships**: DAO/club memberships
- **Services**: Ongoing service agreements

## Security Considerations
- Prevent griefing through spam renewals
- Ensure proper authorization for renewals
- Handle race conditions in auto-renewal
- Implement circuit breakers for mass failures

## References
- [Superfluid CFA](https://docs.superfluid.finance/superfluid/protocol-overview/in-depth-overview/super-agreements/constant-flow-agreement-cfa)
- [LlamaPay Documentation](https://docs.llamapay.io/) 