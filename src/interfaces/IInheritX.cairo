use starknet::ContractAddress;
use crate::types::{ActivityRecord, ActivityType, SimpleBeneficiary, UserProfile};

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

#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub enum PlanStatus {
    Draft,
    Active,
    Executed,
    Cancelled,
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
    fn transfer_funds(ref self: TContractState, beneficiary: ContractAddress, amount: u256);
    fn test_deployment(ref self: TContractState) -> bool;
    fn is_verified(self: @TContractState, user: ContractAddress) -> bool;
    // fn generate_verification_code(ref self: TContractState, user: ContractAddress) -> felt252;
    fn complete_verififcation(ref self: TContractState, user: ContractAddress, code: felt252);
    fn start_verification(ref self: TContractState, user: ContractAddress) -> felt252;
    fn check_expiry(ref self: TContractState, user: ContractAddress) -> bool;
    fn get_verification_status(
        ref self: TContractState, code: felt252, user: ContractAddress,
    ) -> bool;
    fn get_activity_history(
        self: @TContractState, user: ContractAddress, start_index: u256, page_size: u256,
    ) -> Array<ActivityRecord>;

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
    fn override_plan(ref self: TContractState, plan_id: u256);
}
