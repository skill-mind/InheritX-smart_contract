use starknet::ContractAddress;
use crate::types::{
    ActivityRecord, ActivityType, AssetAllocation, InheritancePlan, NotificationSettings,
    NotificationStruct, PlanOverview, PlanSection, SecuritySettings, SimpleBeneficiary, UserProfile,
    Wallet,
};

#[starknet::interface]
pub trait IInheritX<TContractState> {
    fn create_inheritance_plan(
        ref self: TContractState,
        plan_name: felt252,
        tokens: Array<AssetAllocation>,
        description: felt252,
        pick_beneficiaries: Array<ContractAddress>,
    ) -> u256;

    fn write_plan_status(ref self: TContractState, plan_id: u256, status: crate::types::PlanStatus);

    fn write_to_beneficiary_count(ref self: TContractState, plan_id: u256, beneficiary_count: u32);

    fn write_to_asset_count(ref self: TContractState, plan_id: u256, asset_count: u32);

    fn create_claim(
        ref self: TContractState,
        name: felt252,
        email: felt252,
        beneficiary: ContractAddress,
        personal_message: felt252,
        amount: u256,
    ) -> u256;

    fn create_profile(
        ref self: TContractState,
        username: felt252,
        email: felt252,
        full_name: felt252,
        profile_image: felt252,
    ) -> bool;

    fn collect_claim(
        ref self: TContractState,
        inheritance_id: u256,
        beneficiary: ContractAddress,
        claim_code: u256,
    ) -> bool;

    fn get_inheritance_plan(ref self: TContractState, plan_id: u256) -> InheritancePlan;

    fn write_to_inheritance(ref self: TContractState, plan_id: u256, new_plan: InheritancePlan);

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

    fn get_profile(ref self: TContractState, address: ContractAddress) -> UserProfile;

    fn retrieve_claim(ref self: TContractState, inheritance_id: u256) -> SimpleBeneficiary;

    fn transfer_funds(ref self: TContractState, beneficiary: ContractAddress, amount: u256);

    fn test_deployment(ref self: TContractState) -> bool;

    fn start_verification(ref self: TContractState, user: ContractAddress) -> felt252;

    fn check_expiry(ref self: TContractState, user: ContractAddress) -> bool;

    fn complete_verififcation(ref self: TContractState, user: ContractAddress, code: felt252);

    fn get_verification_status(
        ref self: TContractState, code: felt252, user: ContractAddress,
    ) -> bool;

    fn is_verified(self: @TContractState, user: ContractAddress) -> bool;

    fn add_beneficiary(
        ref self: TContractState,
        plan_id: u256,
        name: felt252,
        email: felt252,
        address: ContractAddress,
    ) -> felt252;

    fn set_plan_asset_owner(ref self: TContractState, plan_id: u256, owner: ContractAddress);

    fn set_max_guardians(ref self: TContractState, max_guardian_number: u8);

    fn get_plan_beneficiaries_count(self: @TContractState, plan_id: u256) -> u32;

    fn get_plan_beneficiaries(self: @TContractState, plan_id: u256, index: u32) -> ContractAddress;

    fn get_activity_history(
        self: @TContractState, user: ContractAddress, start_index: u256, page_size: u256,
    ) -> Array<ActivityRecord>;

    fn is_beneficiary(self: @TContractState, plan_id: u256, address: ContractAddress) -> bool;

    fn set_plan_transfer_date(ref self: TContractState, plan_id: u256, date: u64);

    fn get_activity_history_length(self: @TContractState, user: ContractAddress) -> u256;

    fn get_total_plans(self: @TContractState) -> u256;

    fn generate_recovery_code(ref self: TContractState, user: ContractAddress) -> felt252;

    fn generate_claim_code(
        ref self: TContractState,
        beneficiary: ContractAddress,
        benefactor: ContractAddress,
        amount: u256,
    ) -> felt252;

    fn initiate_recovery(
        ref self: TContractState, user: ContractAddress, recovery_method: felt252,
    ) -> felt252;

    fn verify_recovery_code(
        ref self: TContractState, user: ContractAddress, recovery_code: felt252,
    ) -> bool;

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

    fn get_plan_section(self: @TContractState, plan_id: u256, section: PlanSection) -> PlanOverview;

    fn delete_user_profile(ref self: TContractState, address: ContractAddress) -> bool;

    fn update_user_profile(
        ref self: TContractState,
        username: felt252,
        email: felt252,
        full_name: felt252,
        profile_image: felt252,
        notification_settings: NotificationSettings,
        security_settings: SecuritySettings,
    ) -> bool;

    fn get_user_profile(self: @TContractState, user: ContractAddress) -> UserProfile;

    fn update_security_settings(ref self: TContractState, new_settings: SecuritySettings) -> bool;

    fn add_wallet(ref self: TContractState, wallet: ContractAddress, wallet_type: felt252) -> bool;

    fn set_primary_wallet(ref self: TContractState, wallet: ContractAddress) -> bool;

    fn get_primary_wallet(self: @TContractState, user: ContractAddress) -> ContractAddress;

    fn get_user_wallets(self: @TContractState, user: ContractAddress) -> Array<Wallet>;

    fn is_plan_valid(self: @TContractState, plan_id: u256) -> bool;

    fn is_valid_plan_status(self: @TContractState, plan_id: u256) -> bool;

    fn plan_has_been_claimed(self: @TContractState, plan_id: u256) -> bool;

    fn plan_is_active(self: @TContractState, plan_id: u256) -> bool;

    fn plan_has_assets(self: @TContractState, plan_id: u256) -> bool;

    fn check_beneficiary_plan(self: @TContractState, plan_id: u256) -> bool;

    fn store_kyc_details(ref self: TContractState, ipfs_hash: ByteArray) -> bool;

    fn update_kyc_details(ref self: TContractState, new_ipfs_hash: ByteArray) -> ByteArray;

    fn get_kyc_details(self: @TContractState, user: ContractAddress) -> ByteArray;

    fn has_kyc_details(self: @TContractState, user: ContractAddress) -> bool;

    fn delete_kyc_details(ref self: TContractState) -> bool;
}
