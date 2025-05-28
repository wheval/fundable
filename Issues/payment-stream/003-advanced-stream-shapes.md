---
title: Implement advanced stream shapes (exponential, cliff, custom curves)
labels: enhancement, priority-high, feature
assignees: 
---

## Description

Currently, the contract only supports linear streaming. Modern platforms like Sablier V2 offer various stream shapes including exponential, cliff-based, and custom curves. This enables more sophisticated payment schedules for different use cases.

## Requirements

### 1. Stream Shape Types
```cairo
enum StreamShape {
    Linear,         // Current implementation
    Exponential,    // Exponential growth curve
    Cliff,          // Unlock after cliff, then linear
    Stepped,        // Discrete steps/milestones
    Polynomial,     // Custom polynomial curve
    Logarithmic,    // Logarithmic curve
    Custom,         // User-defined curve
}

struct StreamCurve {
    shape: StreamShape,
    parameters: StreamParameters,
    milestones: Array<Milestone>,
    formula: Option<ByteArray>,  // For custom curves
}

struct StreamParameters {
    exponent: u256,          // For exponential curves
    cliff_percentage: u16,    // Percentage unlocked at cliff
    step_count: u32,         // Number of steps
    coefficients: Array<u256>, // For polynomial curves
}
```

### 2. Cliff Streams
```cairo
struct CliffStream {
    stream_id: u256,
    cliff_time: u64,
    cliff_amount: u256,
    post_cliff_rate: u256,
    total_amount: u256,
}

fn create_cliff_stream(
    ref self: ContractState,
    recipient: ContractAddress,
    cliff_duration: u64,
    cliff_percentage: u16,
    total_amount: u256,
    total_duration: u64,
    token: ContractAddress
) -> u256
```

### 3. Exponential Streams
```cairo
fn create_exponential_stream(
    ref self: ContractState,
    recipient: ContractAddress,
    total_amount: u256,
    duration: u64,
    exponent: u256,  // e.g., 2 for quadratic, 3 for cubic
    token: ContractAddress
) -> u256

fn calculate_exponential_amount(
    self: @ContractState,
    stream_id: u256,
    timestamp: u64
) -> u256
```

### 4. Stepped/Milestone Streams
```cairo
struct Milestone {
    timestamp: u64,
    amount: u256,
    description: ByteArray,
    completed: bool,
}

fn create_milestone_stream(
    ref self: ContractState,
    recipient: ContractAddress,
    milestones: Array<Milestone>,
    token: ContractAddress
) -> u256

fn complete_milestone(
    ref self: ContractState,
    stream_id: u256,
    milestone_index: u32
)
```

### 5. Custom Curve Streams
```cairo
struct CustomCurve {
    points: Array<(u64, u256)>,  // (timestamp, cumulative_amount)
    interpolation: InterpolationType,
}

enum InterpolationType {
    Linear,
    Smooth,
    Step,
}

fn create_custom_curve_stream(
    ref self: ContractState,
    recipient: ContractAddress,
    curve: CustomCurve,
    token: ContractAddress
) -> u256
```

### 6. Advanced Calculations
```cairo
fn get_streamed_amount_for_shape(
    self: @ContractState,
    stream_id: u256,
    timestamp: u64
) -> u256

fn get_withdrawable_at_time(
    self: @ContractState,
    stream_id: u256,
    timestamp: u64
) -> u256

fn get_unlock_schedule(
    self: @ContractState,
    stream_id: u256
) -> Array<(u64, u256)>
```

## Acceptance Criteria
- [ ] All stream shapes implemented
- [ ] Accurate calculations for each curve type
- [ ] Gas-efficient curve calculations
- [ ] Cliff streams unlock correctly
- [ ] Exponential curves calculate properly
- [ ] Custom curves interpolate smoothly
- [ ] Comprehensive tests for edge cases
- [ ] Visual documentation of curves

## Technical Notes
- Use fixed-point math for precise calculations
- Optimize gas for complex calculations
- Consider pre-computing values for efficiency
- Implement overflow protection
- Cache frequently accessed calculations

## Use Cases
- **Vesting**: Cliff + linear for equity
- **Bonuses**: Exponential growth incentives
- **Grants**: Milestone-based funding
- **Rewards**: Logarithmic early adopter benefits
- **Custom**: Arbitrary payment schedules

## Security Considerations
- Prevent manipulation of curve parameters
- Ensure no funds can be locked
- Validate custom curves for monotonicity
- Handle precision loss in calculations

## References
- [Sablier V2 Stream Shapes](https://docs.sablier.com/concepts/protocol/stream-shapes)
- [Superfluid Flow Rate](https://docs.superfluid.finance/superfluid/protocol-overview/in-depth-overview/super-agreements/constant-flow-agreement-cfa) 