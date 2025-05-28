---
title: Create stream marketplace for trading and selling payment streams
labels: enhancement, priority-medium, feature
assignees: 
---

## Description

Implement a marketplace where stream NFTs can be traded, sold, or auctioned. This creates liquidity for long-term payment streams and enables new financial instruments, similar to invoice factoring or structured products.

## Requirements

### 1. Marketplace Structure
```cairo
struct StreamListing {
    listing_id: u256,
    stream_id: u256,
    seller: ContractAddress,
    price: u256,
    payment_token: ContractAddress,
    listing_type: ListingType,
    expires_at: u64,
    active: bool,
}

enum ListingType {
    FixedPrice,
    Auction,
    DutchAuction,
    MakeOffer,
    Bundle,
}

struct StreamBundle {
    bundle_id: u256,
    stream_ids: Array<u256>,
    total_value: u256,
    discount_percentage: u16,
}
```

### 2. Listing Management
```cairo
fn list_stream_for_sale(
    ref self: ContractState,
    stream_id: u256,
    price: u256,
    payment_token: ContractAddress,
    listing_type: ListingType
) -> u256

fn update_listing(
    ref self: ContractState,
    listing_id: u256,
    new_price: u256
)

fn cancel_listing(
    ref self: ContractState,
    listing_id: u256
)

fn create_bundle_listing(
    ref self: ContractState,
    stream_ids: Array<u256>,
    bundle_price: u256,
    payment_token: ContractAddress
) -> u256
```

### 3. Trading Functions
```cairo
fn buy_stream(
    ref self: ContractState,
    listing_id: u256
)

fn make_offer(
    ref self: ContractState,
    stream_id: u256,
    offer_amount: u256,
    payment_token: ContractAddress,
    expires_at: u64
) -> u256

fn accept_offer(
    ref self: ContractState,
    offer_id: u256
)

fn counter_offer(
    ref self: ContractState,
    offer_id: u256,
    new_amount: u256
)
```

### 4. Auction System
```cairo
struct Auction {
    auction_id: u256,
    stream_id: u256,
    starting_price: u256,
    reserve_price: u256,
    current_bid: u256,
    highest_bidder: ContractAddress,
    end_time: u64,
    bid_increment: u256,
}

fn create_auction(
    ref self: ContractState,
    stream_id: u256,
    starting_price: u256,
    reserve_price: u256,
    duration: u64
) -> u256

fn place_bid(
    ref self: ContractState,
    auction_id: u256,
    bid_amount: u256
)

fn finalize_auction(
    ref self: ContractState,
    auction_id: u256
)
```

### 5. Valuation & Analytics
```cairo
fn calculate_stream_value(
    self: @ContractState,
    stream_id: u256,
    discount_rate: u256
) -> u256

fn get_stream_apr(
    self: @ContractState,
    stream_id: u256,
    purchase_price: u256
) -> u256

fn get_market_stats(
    self: @ContractState,
    token: ContractAddress
) -> MarketStats

struct MarketStats {
    total_volume: u256,
    average_price: u256,
    total_listings: u256,
    price_range: (u256, u256),
}
```

### 6. Advanced Features
```cairo
// Fractional ownership
fn fractionalize_stream(
    ref self: ContractState,
    stream_id: u256,
    shares: u256
) -> ContractAddress  // Returns fraction token address

// Collateralized loans
fn collateralize_stream(
    ref self: ContractState,
    stream_id: u256,
    loan_amount: u256,
    interest_rate: u256
) -> u256  // Returns loan ID

// Stream derivatives
fn create_stream_option(
    ref self: ContractState,
    stream_id: u256,
    strike_price: u256,
    expiry: u64,
    option_type: OptionType
) -> u256
```

## Acceptance Criteria
- [ ] Streams can be listed for sale
- [ ] Multiple listing types supported
- [ ] Secure transfer of ownership
- [ ] Auction system works correctly
- [ ] Offers and counter-offers functional
- [ ] Bundle sales implemented
- [ ] Valuation calculations accurate
- [ ] Gas-efficient marketplace operations

## Technical Notes
- Implement escrow for secure trades
- Use signature-based offers for gas efficiency
- Consider implementing royalties for original creators
- Optimize storage for large number of listings
- Implement price oracles for valuations

## Use Cases
- **Liquidity**: Sell future income streams for immediate cash
- **Investment**: Buy discounted future cash flows
- **Hedging**: Trade streams to manage risk
- **Arbitrage**: Profit from price differences
- **Collateral**: Use streams as loan collateral

## Security Considerations
- Prevent front-running in auctions
- Ensure atomic swaps for trades
- Validate stream ownership before listing
- Implement circuit breakers for market manipulation
- Secure escrow mechanism

## References
- [OpenSea Seaport Protocol](https://docs.opensea.io/docs/seaport)
- [Sablier V2 NFT](https://docs.sablier.com/concepts/protocol/nft) 