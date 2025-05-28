---
title: Implement platform fee system for sustainability
labels: enhancement, priority-medium, economics
assignees: 
---

## Description

To ensure platform sustainability, implement a configurable fee system that takes a small percentage from donations or withdrawals, similar to GoFundMe's business model.

## Requirements

### 1. Fee Configuration Storage
```cairo
struct FeeConfig {
    donation_fee_bps: u16,      // Fee in basis points (e.g., 250 = 2.5%)
    withdrawal_fee_bps: u16,    // Alternative: fee on withdrawal
    fee_recipient: ContractAddress,
    is_fee_on_donation: bool,   // true = fee on donation, false = fee on withdrawal
}
```

### 2. Fee Management Functions
```cairo
fn set_platform_fee(ref self: ContractState, fee_bps: u16, on_donation: bool) // Owner only
fn set_fee_recipient(ref self: ContractState, recipient: ContractAddress) // Owner only
fn waive_fees_for_campaign(ref self: ContractState, campaign_id: u256) // Owner only
fn get_fee_config(self: @ContractState) -> FeeConfig
```

### 3. Fee Calculation Logic
- Calculate fee: `fee_amount = (amount * fee_bps) / 10000`
- Apply fee during donation or withdrawal based on configuration
- Track total fees collected per asset type
- Support fee waivers for charity campaigns

### 4. Fee Distribution
```cairo
fn withdraw_collected_fees(ref self: ContractState, asset: ContractAddress) // Fee recipient only
fn get_collected_fees(self: @ContractState, asset: ContractAddress) -> u256
```

### 5. Transparency Features
- Emit FeeCollected events with details
- Public view functions for fee rates
- Clear fee breakdown in donation/withdrawal events

## Acceptance Criteria
- [ ] Platform fee configurable by owner
- [ ] Fees correctly calculated and collected
- [ ] Fee waiver mechanism for special campaigns
- [ ] Fee recipient can withdraw collected fees
- [ ] Cannot set fees above maximum (e.g., 10%)
- [ ] Events clearly show fee deductions
- [ ] Tests cover all fee scenarios
- [ ] Gas-efficient fee calculations

## Technical Notes
- Use basis points (bps) for precision without decimals
- Consider different fee structures per asset type
- Implement checks to prevent excessive fees
- Track fees separately from campaign funds

## Business Considerations
- Standard fee: 2.9% + $0.30 per donation (similar to payment processors)
- Consider lower fees for registered charities
- Option for campaign creators to cover donor fees 