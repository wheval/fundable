/// CampaignDonation contract implementation
#[starknet::contract]
pub mod CampaignDonation {
    use core::num::traits::Zero;
    use core::traits::Into;
    use fundable::interfaces::ICampaignDonation::ICampaignDonation;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{
        ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address,
    };
    use crate::base::errors::Errors::{CAMPAIGN_REF_EMPTY, CAMPAIGN_REF_EXISTS, ZERO_AMOUNT};
    use crate::base::types::{Campaigns, Donations};

    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        campaign_counts: u256,
        campaigns: Map<u256, Campaigns>, // (campaign_id, Campaigns)
        // campaign_donation: Map<
        //     (ContractAddress, u256), Donation,
        // >,
        // map(<donor_address, campaign_id>, Donation)
        // donations: Map<(u256, u256), Donations>,
        donations: Map<u256, Map<u256, Donations>>,
        donation_counts: Map<u256, u256>,
        donation_count: u256,
        // cmapaign_withdrawal: Map<
        //     (ContractAddress, u256), CampaignWithdrawal,
        // >, // map<(campaign_owner, campaign_id), CampaignWithdrawal>
        // Track existing campaign refs
        campaign_refs: Map<felt252, bool> // All campaign ref to use for is_campaign_ref_exists
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Campaign: Campaign,
        Donation: Donation,
        CampaignWithdrawal: CampaignWithdrawal,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }


    #[derive(Drop, starknet::Event)]
    pub struct Campaign {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub campaign_reference: felt252,
        #[key]
        pub campaign_id: u256,
        #[key]
        pub asset: felt252,
        #[key]
        pub target_amount: u256,
        #[key]
        pub timestamp: u64,
    }


    #[derive(Drop, starknet::Event)]
    pub struct Donation {
        #[key]
        pub donor: ContractAddress,
        #[key]
        pub campaign_id: u256,
        #[key]
        pub amount: u256,
        #[key]
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CampaignWithdrawal {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub campaign_id: u256,
        #[key]
        pub amount: u256,
        #[key]
        pub timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl CampaignDonationImpl of ICampaignDonation<ContractState> {
        fn create_campaign(
            ref self: ContractState, campaign_ref: felt252, target_amount: u256, asset: felt252,
        ) -> u256 {
            assert(campaign_ref != '', CAMPAIGN_REF_EMPTY);
            assert(!self.campaign_refs.read(campaign_ref), CAMPAIGN_REF_EXISTS);
            assert(target_amount > 0, ZERO_AMOUNT);
            let campaign_id: u256 = self.campaign_counts.read() + 1;
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            let current_amount: u256 = 0;
            let campaign = Campaigns {
                campaign_id,
                owner: caller,
                target_amount,
                current_amount,
                asset,
                campaign_reference: campaign_ref,
                is_closed: false,
                is_goal_reached: false,
            };

            self.campaigns.write(campaign_id, campaign);
            self.campaign_counts.write(campaign_id);
            self.campaign_refs.write(campaign_ref, true);

            self
                .emit(
                    Event::Campaign(
                        Campaign {
                            owner: caller,
                            campaign_reference: campaign_ref,
                            campaign_id,
                            asset,
                            target_amount,
                            timestamp,
                        },
                    ),
                );

            campaign_id
        }

        fn donate_to_campaign(
            ref self: ContractState, campaign_id: u256, amount: u256, token: ContractAddress,
        ) -> u256 {
            assert(amount > 0, 'Cannot donate nothing');
            let donor = get_caller_address();
            let mut campaign = self.get_campaign(campaign_id);
            let contract_address = get_contract_address();
            let timestamp = get_block_timestamp();
            let asset = campaign.asset;
            // Fetch current count and write to (campaign_id, index)
            let donation_id = self.donation_count.read() + 1;

            // Ensure the campaign is still accepting donations
            assert(!campaign.is_goal_reached, 'Target Reached');

            // Prepare the ERC20 interface
            let token_dispatcher = IERC20Dispatcher { contract_address: token };

            // Transfer funds to contract — requires prior approval
            token_dispatcher.transfer_from(donor, contract_address, amount);

            // Update campaign amount
            campaign.current_amount += amount;

            // If goal reached, mark as closed
            if (campaign.current_amount >= campaign.target_amount) {
                campaign.is_goal_reached = true;
                campaign.is_closed = true;
            }

            self.campaigns.write(campaign_id, campaign);

            // Create donation record
            let donation = Donations { donation_id, donor, campaign_id, amount, asset };

            self.donations.entry(campaign_id).entry(donation_id).write(donation);

            self.donation_count.write(donation_id);

            // Update the per-campaign donation count
            let campaign_donation_count = self.donation_counts.read(campaign_id);
            self.donation_counts.write(campaign_id, campaign_donation_count + 1);

            // Emit donation event
            self.emit(Event::Donation(Donation { donor, campaign_id, amount, timestamp }));

            donation_id
        }


        fn withdraw_from_campaign(ref self: ContractState, campaign_id: u256) {}

        fn get_donation(self: @ContractState, campaign_id: u256, donation_id: u256) -> Donations {
            let donations: Donations = self.donations.entry(campaign_id).entry(donation_id).read();
            donations
        }

        fn get_campaigns(self: @ContractState) -> Array<Campaigns> {
            let mut campaigns = ArrayTrait::new();
            let campaigns_count = self.campaign_counts.read();
            
            // Iterate through all campaign IDs (1 to campaigns_count)
            let mut i: u256 = 1;
            while i <= campaigns_count {
                let campaign = self.campaigns.read(i);
                campaigns.append(campaign);
                i += 1;
            }
            
            campaigns
        }
        
        fn get_campagin_donations(self: @ContractState, campaign_id: u256) -> Array<Donations> {
            let mut donations = ArrayTrait::new();
            let donation_count = self.donation_counts.read(campaign_id);
        
            let mut i: u256 = 1;
            while i <= donation_count {
                let donation = self.donations.entry(campaign_id).entry(i).read();
                donations.append(donation);
                i += 1;
            }
            
            donations
        }

        fn get_campaign(self: @ContractState, camapign_id: u256) -> Campaigns {
            let campaign: Campaigns = self.campaigns.read(camapign_id);
            campaign
        }
    }
}
