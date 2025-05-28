---
title: Add stream templates and presets for common use cases
labels: enhancement, priority-medium, user-experience
assignees: 
---

## Description

Implement pre-configured stream templates for common use cases like salaries, vesting schedules, and subscriptions. This feature, inspired by Sablier V2 and LlamaPay, simplifies stream creation and ensures best practices.

## Requirements

### 1. Template Types
```cairo
enum StreamTemplate {
    MonthlySalary,
    BiweeklySalary,
    LinearVesting,
    CliffVesting,
    Subscription,
    Milestone,
    Custom,
}

struct TemplateConfig {
    template_id: u256,
    name: ByteArray,
    description: ByteArray,
    template_type: StreamTemplate,
    default_duration: u64,
    cliff_period: u64,
    unlock_percentage: u16,
    recurring: bool,
    auto_renew: bool,
    customizable_fields: Array<felt252>,
}
```

### 2. Vesting Templates
```cairo
struct VestingSchedule {
    cliff_duration: u64,        // Initial lock period
    cliff_amount: u256,         // Amount unlocked at cliff
    linear_duration: u64,       // Linear vesting period after cliff
    total_amount: u256,
    revocable: bool,
    accelerated_vesting: bool,  // For acquisition events
}

fn create_vesting_stream(
    ref self: ContractState,
    recipient: ContractAddress,
    schedule: VestingSchedule,
    token: ContractAddress
) -> u256
```

### 3. Salary Templates
```cairo
struct SalaryConfig {
    amount_per_period: u256,
    pay_frequency: PayFrequency,
    start_date: u64,
    probation_period: u64,
    allow_advance: bool,
    max_advance_percentage: u16,
}

enum PayFrequency {
    Weekly,
    Biweekly,
    Monthly,
    Quarterly,
}

fn create_salary_stream(
    ref self: ContractState,
    employee: ContractAddress,
    config: SalaryConfig,
    token: ContractAddress
) -> u256
```

### 4. Subscription Templates
```cairo
struct SubscriptionConfig {
    amount: u256,
    billing_period: u64,
    grace_period: u64,
    auto_renew: bool,
    cancellation_notice: u64,
    trial_period: u64,
}

fn create_subscription_stream(
    ref self: ContractState,
    subscriber: ContractAddress,
    provider: ContractAddress,
    config: SubscriptionConfig,
    token: ContractAddress
) -> u256
```

### 5. Template Management
```cairo
fn register_template(
    ref self: ContractState,
    config: TemplateConfig
) -> u256

fn update_template(
    ref self: ContractState,
    template_id: u256,
    config: TemplateConfig
)

fn get_template(
    self: @ContractState,
    template_id: u256
) -> TemplateConfig

fn get_popular_templates(
    self: @ContractState,
    limit: u32
) -> Array<TemplateConfig>
```

## Acceptance Criteria
- [ ] All template types implemented
- [ ] Templates simplify stream creation
- [ ] Vesting schedules work with cliffs
- [ ] Salary streams handle pay periods correctly
- [ ] Subscriptions auto-renew when configured
- [ ] Templates are customizable
- [ ] Gas-efficient template usage
- [ ] Comprehensive documentation for each template

## Technical Notes
- Store templates efficiently to minimize gas
- Use inheritance/composition for template logic
- Implement template versioning for upgrades
- Consider template marketplace for community templates

## Use Cases
- **Startups**: Employee vesting schedules
- **DAOs**: Contributor compensation
- **Freelancers**: Recurring client payments
- **SaaS**: Subscription management
- **Investors**: Token vesting

## Future Enhancements
- Template marketplace
- Custom template builder UI
- Template analytics
- Industry-specific templates
- Multi-sig template approval

## References
- [Sablier V2 Shapes](https://docs.sablier.com/concepts/protocol/stream-shapes)
- [LlamaPay Streams](https://docs.llamapay.io/) 