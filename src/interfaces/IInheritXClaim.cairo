use core::array::Array;
use starknet::ContractAddress;

#[starknet::interface]
pub trait IInheritXClaim<TContractState> {
    // Core Claim Functions

    // Initialize a new claim with a claim code
    fn initiate_claim(
        ref self: TContractState, plan_id: u256, beneficiary: ContractAddress, claim_code: u256,
    ) -> felt252;

    // Get all claims for a beneficiary
    fn get_beneficiary_claims(
        self: @TContractState, beneficiary: ContractAddress,
    ) -> Array<felt252>;

    // View claim preview with all details
    fn get_claim_overview(self: @TContractState, claim_id: u256) -> felt252;

    // View claim status (pending, approved, rejected, etc.)
    fn get_claim_status(self: @TContractState, claim_id: u256) -> felt252;

    // Function for guardians or plan owners to approve a claim
    fn approve_claim(ref self: TContractState, claim_id: u256, approver: ContractAddress) -> bool;

    // Function to reject invalid claims
    fn reject_claim(
        ref self: TContractState, claim_id: u256, rejector: ContractAddress, reason: felt252,
    ) -> bool;

    // Function to process approved claims
    fn execute_claim(ref self: TContractState, claim_id: u256) -> bool;

    // Function to verify claim codes are valid
    fn validate_claim_code(self: @TContractState, plan_id: u256, claim_code: u256) -> bool;
}

