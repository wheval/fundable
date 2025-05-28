use crate::base::types::{Campaigns, Donations};

/// Interface for the Campaign Donation contract
///
/// This interface defines the core functionality for managing crowdfunding campaigns,
/// including creating campaigns, accepting donations, and withdrawing funds.
#[starknet::interface]
pub trait ICampaignDonation<TContractState> {
    // *************************************************************************
    //                              EXTERNAL FUNCTIONS
    // *************************************************************************

    /// Creates a new fundraising campaign
    ///
    /// # Arguments
    /// * `campaign_ref` - A unique 5-character identifier for the campaign
    /// * `target_amount` - The fundraising goal amount in the donation token
    ///
    /// # Returns
    /// * `u256` - The newly created campaign's ID
    ///
    /// # Panics
    /// * If `campaign_ref` is empty
    /// * If `campaign_ref` already exists
    /// * If `target_amount` is zero
    fn create_campaign(
        ref self: TContractState, campaign_ref: felt252, target_amount: u256,
    ) -> u256;

    /// Makes a donation to a specific campaign
    ///
    /// # Arguments
    /// * `campaign_id` - The ID of the campaign to donate to
    /// * `amount` - The amount to donate in the campaign's donation token
    ///
    /// # Returns
    /// * `u256` - The donation ID for this contribution
    ///
    /// # Requirements
    /// * Donor must have approved the contract to spend the donation amount
    /// * Campaign must not have reached its goal yet
    /// * Amount must be greater than zero
    /// * Amount cannot exceed the campaign's target amount
    ///
    /// # Effects
    /// * Transfers tokens from donor to contract
    /// * Updates campaign balance
    /// * Marks campaign as closed if target is reached
    fn donate_to_campaign(ref self: TContractState, campaign_id: u256, amount: u256) -> u256;

    /// Withdraws all funds from a completed campaign
    ///
    /// # Arguments
    /// * `campaign_id` - The ID of the campaign to withdraw from
    ///
    /// # Requirements
    /// * Caller must be the campaign owner
    /// * Campaign must be closed (goal reached)
    /// * Funds must not have been withdrawn already
    ///
    /// # Effects
    /// * Transfers all campaign funds to the campaign owner
    /// * Marks the campaign as withdrawn
    /// * Emits a CampaignWithdrawal event
    fn withdraw_from_campaign(ref self: TContractState, campaign_id: u256);

    // *************************************************************************
    //                              GETTER FUNCTIONS
    // *************************************************************************

    /// Retrieves all campaigns created in the contract
    ///
    /// # Returns
    /// * `Array<Campaigns>` - An array containing all campaign data
    fn get_campaigns(self: @TContractState) -> Array<Campaigns>;

    /// Retrieves a specific donation by campaign and donation ID
    ///
    /// # Arguments
    /// * `campaign_id` - The ID of the campaign
    /// * `donation_id` - The ID of the donation
    ///
    /// # Returns
    /// * `Donations` - The donation data, or an empty donation struct if not found
    fn get_donation(self: @TContractState, campaign_id: u256, donation_id: u256) -> Donations;

    /// Retrieves detailed information about a specific campaign
    ///
    /// # Arguments
    /// * `campaign_id` - The ID of the campaign to query
    ///
    /// # Returns
    /// * `Campaigns` - The campaign data including owner, target, balance, etc.
    fn get_campaign(self: @TContractState, campaign_id: u256) -> Campaigns;

    /// Retrieves all donations made to a specific campaign
    ///
    /// # Arguments
    /// * `campaign_id` - The ID of the campaign
    ///
    /// # Returns
    /// * `Array<Donations>` - An array of all donations made to the campaign
    fn get_campaign_donations(self: @TContractState, campaign_id: u256) -> Array<Donations>;
}
