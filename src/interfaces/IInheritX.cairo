use starknet::ContractAddress;
use crate::types::{
    ActivityRecord, ActivityType, NotificationSettings, NotificationStruct, PlanOverview,
    PlanSection, SecuritySettings, SimpleBeneficiary, TokenInfo, UserProfile, Wallet,
};

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct InheritancePlan {
    pub owner: ContractAddress,
    // pub time_lock_period: u64,
    // pub required_guardians: u8,
    pub is_active: bool,
    pub is_claimed: bool,
    pub total_value: u256,
    pub plan_name: felt252,
    pub description: felt252,
}

#[derive(Drop, Serde, starknet::Store, Copy)]
pub struct AssetAllocation {
    pub token: ContractAddress,
    pub amount: u256,
    pub percentage: u8,
}

#[derive(Copy, Drop, Serde)]
pub struct MediaMessage {
    pub plan_id: felt252,
    pub media_type: felt252,
    pub media_content: felt252,
}

#[starknet::interface]
pub trait IInheritX<TContractState> {
    // Initialize a new claim with a claim code
    fn create_claim(
        ref self: TContractState,
        name: felt252,
        email: felt252,
        beneficiary: ContractAddress,
        personal_message: felt252,
        amount: u256,
        claim_code: u256,
    ) -> u256;

    fn collect_claim(
        ref self: TContractState,
        inheritance_id: u256,
        beneficiary: ContractAddress,
        claim_code: u256,
    ) -> bool;

    fn create_inheritance_plan(
        ref self: TContractState,
        plan_name: felt252,
        tokens: Array<AssetAllocation>,
        description: felt252,
        pick_beneficiaries: Array<ContractAddress>,
    ) -> u256;
    // Getters
    fn get_inheritance_plan(ref self: TContractState, plan_id: u256) -> InheritancePlan;
    fn add_beneficiary(
        ref self: TContractState,
        plan_id: u256,
        name: felt252,
        email: felt252,
        address: ContractAddress,
    ) -> felt252;
    fn is_beneficiary(self: @TContractState, plan_id: u256, address: ContractAddress) -> bool;
    fn get_plan_beneficiaries(self: @TContractState, plan_id: u256, index: u32) -> ContractAddress;
    fn get_plan_beneficiaries_count(self: @TContractState, plan_id: u256) -> u32;
    fn set_max_guardians(ref self: TContractState, max_guardian_number: u8);
    fn set_plan_transfer_date(ref self: TContractState, plan_id: u256, date: u64);
    fn set_plan_asset_owner(ref self: TContractState, plan_id: u256, owner: ContractAddress);
    fn record_user_activity(
        ref self: TContractState,
        user: ContractAddress,
        activity_type: ActivityType,
        details: felt252,
        ip_address: felt252,
        device_info: felt252,
    ) -> u256;

    fn get_user_activity(
        ref self: TContractState, user: ContractAddress, activity_id: u256,
    ) -> ActivityRecord;

    fn retrieve_claim(ref self: TContractState, inheritance_id: u256) -> SimpleBeneficiary;
    fn get_plan_section(self: @TContractState, plan_id: u256, section: PlanSection) -> PlanOverview;
    fn transfer_funds(ref self: TContractState, beneficiary: ContractAddress, amount: u256);
    fn test_deployment(ref self: TContractState) -> bool;
 feat/getTotalActivity
    fn get_total_assets_value(self: @TContractState) -> u256;
}



    fn is_verified(self: @TContractState, user: ContractAddress) -> bool;
    // fn generate_verification_code(ref self: TContractState, user: ContractAddress) -> felt252;
    fn complete_verififcation(ref self: TContractState, user: ContractAddress, code: felt252);
    fn start_verification(ref self: TContractState, user: ContractAddress) -> felt252;
    fn check_expiry(ref self: TContractState, user: ContractAddress) -> bool;
    fn get_verification_status(
        ref self: TContractState, code: felt252, user: ContractAddress,
    ) -> bool;
 main
    fn get_activity_history(
        self: @TContractState, user: ContractAddress, start_index: u256, page_size: u256,
    ) -> Array<ActivityRecord>;

    fn get_total_activities(self: @ContractState) -> u64

    fn get_activity_history_length(self: @TContractState, user: ContractAddress) -> u256;
    fn get_total_plans(self: @TContractState) -> u256;
    fn create_profile(
        ref self: TContractState,
        username: felt252,
        email: felt252,
        full_name: felt252,
        profile_image: felt252,
    ) -> bool;
    fn get_profile(ref self: TContractState, address: ContractAddress) -> UserProfile;
 feat/getTotalActivity
 feat/getTotalActivity
 main


    fn update_notification(
        ref self: TContractState,
        user: ContractAddress,
        email_notifications: bool,
        push_notifications: bool,
        claim_alerts: bool,
        plan_updates: bool,
        security_alerts: bool,
        marketing_updates: bool,
    ) -> NotificationStruct;

    fn get_all_notification_preferences(
        ref self: TContractState, user: ContractAddress,
    ) -> NotificationStruct;
 main

    fn delete_user_profile(ref self: TContractState, address: ContractAddress) -> bool;
 feat/getTotalActivity
 main

    fn update_user_profile(
        ref self: TContractState,
        username: felt252,
        email: felt252,
        full_name: felt252,
        profile_image: felt252,
        notification_settings: NotificationSettings,
        security_settings: SecuritySettings,
    ) -> bool;

    fn _update_notification_settings(
        ref self: TContractState, user: ContractAddress, settings: NotificationSettings,
    );

    fn _record_activity(
        ref self: TContractState,
        user: ContractAddress,
        activity_type: ActivityType,
        details: felt252,
    );

    fn get_user_profile(self: @TContractState, user: ContractAddress) -> UserProfile;

    fn update_security_settings(ref self: TContractState, new_settings: SecuritySettings) -> bool;


    // New Wallet Management Methods
    fn add_wallet(ref self: TContractState, wallet: ContractAddress, wallet_type: felt252) -> bool;
    fn set_primary_wallet(ref self: TContractState, wallet: ContractAddress) -> bool;
    fn get_primary_wallet(self: @TContractState, user: ContractAddress) -> ContractAddress;
    fn get_user_wallets(self: @TContractState, user: ContractAddress) -> Array<Wallet>;
 main
}
