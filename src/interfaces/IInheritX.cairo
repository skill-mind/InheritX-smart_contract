use starknet::ContractAddress;
use crate::types::SimpleBeneficiary;
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct InheritancePlan {
    pub owner: ContractAddress,
    pub time_lock_period: u64,
    pub required_guardians: u8,
    pub is_active: bool,
    pub is_claimed: bool,
    pub total_value: u256,
}

#[derive(Drop, Serde, starknet::Store, Copy)]
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

    fn create_inheritance_plan(
        ref self: TContractState,
        time_lock_period: u64,
        required_guardians: u8,
        guardians: Array<ContractAddress>,
        assets: Array<AssetAllocation>,
    ) -> u256;

    fn retrieve_claim(ref self: TContractState, inheritance_id: u256) -> SimpleBeneficiary;
    fn transfer_funds(ref self: TContractState, beneficiary: ContractAddress, amount: u256);
    fn test_deployment(ref self: TContractState) -> bool;
    // Getters
    fn get_inheritance_plan(ref self: TContractState, plan_id: u256) -> InheritancePlan;
}
