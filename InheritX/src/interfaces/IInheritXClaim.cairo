use starknet::ContractAddress;
use core::array::Array;

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
}

