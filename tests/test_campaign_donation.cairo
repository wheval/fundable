use core::array::ArrayTrait;
use core::traits::Into;
use fundable::base::types::{Campaigns, Donations};
use fundable::campaign_donation::CampaignDonation;
use fundable::interfaces::ICampaignDonation::{
    ICampaignDonationDispatcher, ICampaignDonationDispatcherTrait,
};
use openzeppelin::access::accesscontrol::interface::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc721::interface::{
    IERC721Dispatcher, IERC721DispatcherTrait, IERC721MetadataDispatcher,
    IERC721MetadataDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpy, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address, test_address,
};
use starknet::{ContractAddress, contract_address_const};


fn setup() -> (ContractAddress, ContractAddress, ICampaignDonationDispatcher, IERC721Dispatcher) {
    let sender: ContractAddress = contract_address_const::<'sender'>();
    // Deploy mock ERC20
    let erc20_class = declare("MockUsdc").unwrap().contract_class();
    let mut calldata = array![sender.into(), sender.into(), 6];
    let (erc20_address, _) = erc20_class.deploy(@calldata).unwrap();

    // Deploy Campaign Donation contract
    let protocol_owner: ContractAddress = contract_address_const::<'protocol_owner'>();
    let campaign_donation_class = declare("CampaignDonation").unwrap().contract_class();
    let mut calldata = array![protocol_owner.into()];
    let (campaign_donation_address, _) = campaign_donation_class.deploy(@calldata).unwrap();

    (
        erc20_address,
        sender,
        ICampaignDonationDispatcher { contract_address: campaign_donation_address },
        IERC721Dispatcher { contract_address: campaign_donation_address },
    )
}


#[test]
fn test_successful_create_campaign() {
    let (_token_address, _sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;
    let asset = 'Test';
    let campaign_ref = 'Test';
    let owner = contract_address_const::<'owner'>();

    start_cheat_caller_address(campaign_donation.contract_address, owner);
    let campaign_id = campaign_donation.create_campaign(campaign_ref, target_amount, asset);
    stop_cheat_caller_address(campaign_donation.contract_address);
    // This is the first Campaign Created, so it will be 1.
    assert!(campaign_id == 1_u256, "Campaign creation failed");

    let campaign = campaign_donation.get_campaign(campaign_id);
    assert(campaign.campaign_id == campaign_id, 'Campaign ID mismatch');
    assert(campaign.owner == owner, 'Owner mismatch');
    assert(campaign.target_amount == target_amount, 'Target amount mismatch');
    assert(campaign.current_amount == 0.into(), 'Current amount should be 0');
    assert(campaign.asset == asset, 'Asset mismatch');
    assert(campaign.campaign_reference == campaign_ref, 'Reference mismatch');
    assert(!campaign.is_closed, 'Campaign should not be closed');
    assert(!campaign.is_goal_reached, 'Goal should not be reached');
}

#[test]
#[should_panic(expected: 'Error: Amount must be > 0.')]
fn test_create_campaign_invalid_zero_amount() {
    let (_token_address, _sender, campaign_donation, _erc721) = setup();
    let target_amount = 0_u256;
    let asset = 'Test';
    let campaign_ref = 'Test';
    let owner = contract_address_const::<'owner'>();
    start_cheat_caller_address(campaign_donation.contract_address, owner);
    campaign_donation.create_campaign(campaign_ref, target_amount, asset);
    stop_cheat_caller_address(campaign_donation.contract_address);
}

#[test]
#[should_panic(expected: 'Error: Campaign Ref Exists')]
fn test_create_campaign_duplicate_campaign_refs() {
    let (_token_address, _sender, campaign_donation, _erc721) = setup();
    let target_amount = 50_u256;
    let asset = 'Test';
    let campaign_ref = 'Test';
    let owner = contract_address_const::<'owner'>();
    start_cheat_caller_address(campaign_donation.contract_address, owner);
    campaign_donation.create_campaign(campaign_ref, target_amount, asset);
    campaign_donation.create_campaign(campaign_ref, target_amount, asset);
    stop_cheat_caller_address(campaign_donation.contract_address);
}

#[test]
#[should_panic(expected: 'Error: Campaign Ref Is Required')]
fn test_create_campaign_empty_campaign_refs() {
    let (_token_address, _sender, campaign_donation, _erc721) = setup();
    let target_amount = 100_u256;
    let asset = 'Test';
    let campaign_ref = '';
    let owner = contract_address_const::<'owner'>();
    start_cheat_caller_address(campaign_donation.contract_address, owner);
    campaign_donation.create_campaign(campaign_ref, target_amount, asset);
    stop_cheat_caller_address(campaign_donation.contract_address);
}
#[test]
fn test_successful_campaign_donation() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;
    let asset = 'Test';
    let campaign_ref = 'Test';

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign(campaign_ref, target_amount, asset);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // This is the first Campaign Created, so it will be 1.
    assert!(campaign_id == 1_u256, "Campaign creation failed");

    stop_cheat_caller_address(campaign_donation.contract_address);

    let user_balance_before = token_dispatcher.balance_of(sender);
    let contract_balance_before = token_dispatcher.balance_of(campaign_donation.contract_address);

    // Simulate delegate's approval:
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, 1000);
    stop_cheat_caller_address(token_address);

    let allowance = token_dispatcher.allowance(sender, campaign_donation.contract_address);
    assert(allowance >= 1000, 'Allowance not set correctly');
    println!("Allowance for withdrawal: {}", allowance);

    start_cheat_caller_address(campaign_donation.contract_address, sender);

    let donation_id = campaign_donation.donate_to_campaign(campaign_id, 500, token_address);

    stop_cheat_caller_address(campaign_donation.contract_address);

    let donation = campaign_donation.get_donation(campaign_id, donation_id);
    assert(donation.donation_id == 1, ' not initalized Properly');
    assert(donation.donor == sender, 'sender failed');
    assert(donation.campaign_id == campaign_id, 'campaing id failed');
    assert(donation.amount == 500, 'fund not eflecting');
    assert(donation.asset == asset, 'asset failed');

    let user_balance_after = token_dispatcher.balance_of(sender);
    let contract_balance_after = token_dispatcher.balance_of(campaign_donation.contract_address);
    assert(
        (contract_balance_before == 0) && (contract_balance_after == 500), 'CON transfer failed',
    );
    assert(user_balance_after == user_balance_before - 500, ' USR transfer failed');
}


#[test]
fn test_successful_campaign_donation_twice() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;
    let asset = 'Test';
    let campaign_ref = 'Test';

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign(campaign_ref, target_amount, asset);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // This is the first Campaign Created, so it will be 1.
    assert!(campaign_id == 1_u256, "Campaign creation failed");

    stop_cheat_caller_address(campaign_donation.contract_address);

    let user_balance_before = token_dispatcher.balance_of(sender);
    let contract_balance_before = token_dispatcher.balance_of(campaign_donation.contract_address);

    // Simulate delegate's approval:
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, 1000);
    stop_cheat_caller_address(token_address);

    let allowance = token_dispatcher.allowance(sender, campaign_donation.contract_address);
    assert(allowance >= 1000, 'Allowance not set correctly');
    println!("Allowance for withdrawal: {}", allowance);

    start_cheat_caller_address(campaign_donation.contract_address, sender);

    let _donation_id = campaign_donation.donate_to_campaign(campaign_id, 500, token_address);
    let donation_id_1 = campaign_donation.donate_to_campaign(campaign_id, 300, token_address);

    stop_cheat_caller_address(campaign_donation.contract_address);

    let donation = campaign_donation.get_donation(campaign_id, donation_id_1);

    assert(donation.donation_id == 2, ' not initalized Properly');
    assert(donation.amount == 300, 'fund not eflecting');

    let user_balance_after = token_dispatcher.balance_of(sender);
    let contract_balance_after = token_dispatcher.balance_of(campaign_donation.contract_address);
    assert((contract_balance_before == 0) && (contract_balance_after == 800), 'transfer failed');
    assert(user_balance_after == user_balance_before - 800, ' USR transfer failed');
}


#[test]
fn test_successful_multiple_users_donating_to_a_campaign() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;
    let asset = 'Test';
    let campaign_ref = 'Test';
    let another_user: ContractAddress = contract_address_const::<'another_user'>();

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign(campaign_ref, target_amount, asset);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // This is the first Campaign Created, so it will be 1.
    assert!(campaign_id == 1_u256, "Campaign creation failed");

    stop_cheat_caller_address(campaign_donation.contract_address);

    let contract_balance_before = token_dispatcher.balance_of(campaign_donation.contract_address);

    // Simulate delegate's approval:
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, 100000);
    token_dispatcher.transfer(another_user, 10000);
    let other_user_balance_before = token_dispatcher.balance_of(another_user);
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(token_address, another_user);
    token_dispatcher.approve(campaign_donation.contract_address, 100000);
    stop_cheat_caller_address(token_address);

    let allowance = token_dispatcher.allowance(sender, campaign_donation.contract_address);
    assert(allowance >= 1000, 'Allowance not set correctly');
    println!("Allowance for withdrawal: {}", allowance);

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let _donation_id = campaign_donation.donate_to_campaign(campaign_id, 500, token_address);
    stop_cheat_caller_address(campaign_donation.contract_address);

    start_cheat_caller_address(campaign_donation.contract_address, another_user);
    let donation_id_1 = campaign_donation.donate_to_campaign(campaign_id, 300, token_address);
    stop_cheat_caller_address(campaign_donation.contract_address);

    let donation = campaign_donation.get_donation(campaign_id, donation_id_1);

    assert(donation.donation_id == 2, ' not initalized Properly');
    assert(donation.amount == 300, 'fund not eflecting');

    let other_user_balance_after = token_dispatcher.balance_of(another_user);
    let contract_balance_after = token_dispatcher.balance_of(campaign_donation.contract_address);
    assert((contract_balance_before == 0) && (contract_balance_after == 800), 'transfer failed');
    // assert(other_user_balance_after == other_user_balance_before - 300, ' USR transfer failed');
}
#[test]
fn test_target_met_successful() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;
    let asset = 'Test';
    let campaign_ref = 'Test';

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign(campaign_ref, target_amount, asset);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // This is the first Campaign Created, so it will be 1.
    assert!(campaign_id == 1_u256, "Campaign creation failed");

    stop_cheat_caller_address(campaign_donation.contract_address);

    // Simulate delegate's approval:
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, 10000);
    stop_cheat_caller_address(token_address);

    let allowance = token_dispatcher.allowance(sender, campaign_donation.contract_address);
    assert(allowance >= 1000, 'Allowance not set correctly');
    println!("Allowance for withdrawal: {}", allowance);

    start_cheat_caller_address(campaign_donation.contract_address, sender);

    let _donation_id = campaign_donation.donate_to_campaign(campaign_id, 1001, token_address);

    stop_cheat_caller_address(campaign_donation.contract_address);

    let campaign = campaign_donation.get_campaign(campaign_id);

    assert(campaign.is_goal_reached, 'target error');
    assert(campaign.is_closed, 'target error');
}
