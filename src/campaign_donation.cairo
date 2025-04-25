/// CampaignDonation contract implementation
#[starknet::contract]
pub mod CampaignDonation {
    use core::num::traits::Zero;
    use core::traits::Into;
    use fundable::interfaces::ICampaignDonation::ICampaignDonation;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{
        ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address,
    };
    use crate::base::errors::Errors::ZERO_AMOUNT;
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
        campaign_donation: Map<
            (ContractAddress, u256), Donation,
        >, // map(<donor_address, campaign_id>, Donation)
        cmapaign_withdrawal: Map<
            (ContractAddress, u256), CampaignWithdrawal,
        > // map<(campaign_owner, campaign_id), CampaignWithdrawal>
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

        fn donate_to_campaign(ref self: ContractState, campaign_id: u256, amount: u256) {}

        fn withdraw_from_campaign(ref self: ContractState, campaign_id: u256) {}

        fn get_campaigns(self: @ContractState) -> Array<Campaigns> {
            let campaigns = self._get_campaigns();
            campaigns
        }

        fn get_campaign(self: @ContractState, camapign_id: u256) -> Campaigns {
            let campaign: Campaigns = self.campaigns.read(camapign_id);
            campaign
        }

        fn get_campagin_donations(self: @ContractState, camapign_id: u256) -> Array<Donations> {
            let campaign_donations = self._get_campaign_donations();
            campaign_donations
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _get_campaigns(self: @ContractState) -> Array<Campaigns> {
            let mut campaigns = ArrayTrait::new();
            campaigns
        }
        fn _get_campaign_donations(self: @ContractState) -> Array<Donations> {
            let mut donations = ArrayTrait::new();
            donations
        }
    }
}
