use starknet::ContractAddress;
use starknet::testing::{set_caller_address, set_contract_address};
use starknet::class_hash::ClassHash;
use starknet::contract_address::contract_address_const;
// Import the contract modules
use inheritx::imple::InheritXClaim::InheritxClaim;
use inheritx::imple::InheritXPlan::InheritxPlan;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};


use inheritx::interfaces::IInheritXClaim::{
    IInheritXClaim, IInheritXClaimDispatcher, IInheritXClaimDispatcherTrait,
};


// Test function to set up contracts
#[test]
fn test_setup() {
    // Deploy the plan contract
    let contract_class = declare("InheritxClaim").unwrap().contract_class();

    // TODO: Use Create a contract dispatcher
    let (contract_address, _) = contract_class.deploy(@array![]).unwrap();

    contract_address;

    // Create a claim contract dispatcher
    let claim_dispatcher = IInheritXClaimDispatcher { contract_address: contract_address };
}


