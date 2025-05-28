---
title: Enhance stream composability and DeFi integrations
labels: enhancement, priority-high, defi
assignees: 
---

## Description

Make payment streams composable with other DeFi protocols, enabling use cases like stream-backed loans, yield generation, and automated treasury management. This follows the composability patterns of Superfluid and Sablier V2.

## Requirements

### 1. Stream Wrapping & Unwrapping
```cairo
interface IStreamWrapper {
    fn wrap_stream(stream_id: u256) -> ContractAddress;
    fn unwrap_stream(wrapped_token: ContractAddress) -> u256;
    fn get_underlying_stream(wrapped_token: ContractAddress) -> Stream;
}

struct WrappedStream {
    stream_id: u256,
    wrapper_token: ContractAddress,
    total_supply: u256,
    underlying_value: u256,
}

fn create_wrapped_stream_token(
    ref self: ContractState,
    stream_id: u256,
    name: ByteArray,
    symbol: ByteArray
) -> ContractAddress
```

### 2. Yield Generation
```cairo
struct YieldStrategy {
    strategy_id: u256,
    protocol: YieldProtocol,
    apy: u256,
    risk_level: RiskLevel,
    min_deposit: u256,
}

enum YieldProtocol {
    Lending,      // Aave, Compound style
    Staking,      // Stake streaming tokens
    LiquidityPool, // AMM LP positions
    Vault,        // Yearn-style vaults
}

fn deploy_to_yield(
    ref self: ContractState,
    stream_id: u256,
    strategy_id: u256,
    amount: u256
) -> u256  // Returns position ID

fn harvest_yield(
    ref self: ContractState,
    position_id: u256
) -> u256  // Returns yield amount
```

### 3. Stream-Backed Loans
```cairo
struct StreamLoan {
    loan_id: u256,
    borrower: ContractAddress,
    collateral_stream_id: u256,
    loan_amount: u256,
    interest_rate: u256,
    ltv_ratio: u16,  // Loan-to-value ratio
    liquidation_threshold: u16,
    repaid_amount: u256,
}

fn borrow_against_stream(
    ref self: ContractState,
    stream_id: u256,
    loan_amount: u256,
    duration: u64
) -> u256  // Returns loan ID

fn repay_loan(
    ref self: ContractState,
    loan_id: u256,
    amount: u256
)

fn liquidate_undercollateralized_loan(
    ref self: ContractState,
    loan_id: u256
)
```

### 4. Automated Actions
```cairo
struct StreamAutomation {
    automation_id: u256,
    stream_id: u256,
    trigger: AutomationTrigger,
    action: AutomationAction,
    parameters: Array<felt252>,
    active: bool,
}

enum AutomationTrigger {
    TimeBasedTrigger(u64),           // Execute at specific time
    BalanceThreshold(u256),          // When balance reaches threshold
    PriceCondition(ContractAddress, u256), // Token price condition
    StreamCompletion,                // When stream ends
}

enum AutomationAction {
    SwapTokens,
    TransferToAddress,
    DepositToProtocol,
    CreateNewStream,
    CompoundYield,
}

fn create_automation(
    ref self: ContractState,
    stream_id: u256,
    trigger: AutomationTrigger,
    action: AutomationAction,
    parameters: Array<felt252>
) -> u256
```

### 5. Cross-Protocol Integration
```cairo
interface IProtocolAdapter {
    fn deposit(stream_id: u256, amount: u256) -> bool;
    fn withdraw(position_id: u256, amount: u256) -> bool;
    fn get_balance(position_id: u256) -> u256;
}

// Example: Aave Adapter
fn deposit_to_aave(
    ref self: ContractState,
    stream_id: u256,
    amount: u256
) -> ContractAddress  // Returns aToken address

// Example: Uniswap Adapter
fn provide_liquidity(
    ref self: ContractState,
    stream_id: u256,
    token_b: ContractAddress,
    amount_a: u256,
    amount_b: u256
) -> u256  // Returns LP token amount
```

### 6. Stream Hooks & Callbacks
```cairo
interface IStreamHook {
    fn on_stream_created(stream_id: u256);
    fn on_withdrawal(stream_id: u256, amount: u256);
    fn on_stream_cancelled(stream_id: u256);
    fn on_stream_completed(stream_id: u256);
}

fn register_hook(
    ref self: ContractState,
    stream_id: u256,
    hook: ContractAddress
)

fn execute_hooks(
    ref self: ContractState,
    stream_id: u256,
    hook_type: HookType
)
```

## Acceptance Criteria
- [ ] Streams can be wrapped as ERC20 tokens
- [ ] Yield strategies integrated successfully
- [ ] Stream-backed loans functional
- [ ] Automated actions execute correctly
- [ ] Cross-protocol deposits/withdrawals work
- [ ] Hooks system triggers properly
- [ ] Gas-efficient composability
- [ ] Security audits passed

## Technical Notes
- Implement standard interfaces for compatibility
- Use adapter pattern for protocol integrations
- Ensure atomic operations where needed
- Handle protocol failures gracefully
- Optimize for minimal external calls

## Use Cases
- **Treasury Management**: Auto-deploy idle funds
- **Salary Optimization**: Earn yield on streaming salaries
- **Cash Flow Financing**: Borrow against future income
- **Automated DCA**: Dollar-cost averaging with streams
- **Protocol Treasuries**: Diversified yield generation

## Security Considerations
- Validate all external protocol calls
- Implement emergency pause mechanisms
- Set conservative LTV ratios for loans
- Monitor for oracle manipulation
- Audit all integration points

## References
- [Superfluid Super Apps](https://docs.superfluid.finance/superfluid/developers/super-apps)
- [Sablier V2 Integrations](https://docs.sablier.com/concepts/integrations) 