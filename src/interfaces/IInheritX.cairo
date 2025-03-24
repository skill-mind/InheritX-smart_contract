use starknet::ContractAddress;
use crate::types::{SimpleBeneficiary, ActivityType, ActivityRecord};

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct InheritancePlan {
    owner: ContractAddress,
    time_lock_period: u64,
    required_guardians: u8,
    is_active: bool,
    is_claimed: bool,
    total_value: u256,
}

#[derive(Drop, Serde)]
pub struct AssetAllocation {
    pub token: ContractAddress,
    pub amount: u256,
    pub percentage: u8,
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
}
