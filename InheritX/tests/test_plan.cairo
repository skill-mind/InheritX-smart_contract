use starknet::ContractAddress;
use starknet::testing::{set_caller_address, set_contract_address};
use starknet::class_hash::ClassHash;
use starknet::contract_address::contract_address_const;
// Import the contract modules
use inheritx::imple::InheritXClaim::InheritxClaim;
use inheritx::imple::InheritXPlan::InheritxPlan;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};


use inheritx::interfaces::IInheritXPlan::{
    IInheritXPlan, IInheritXPlanDispatcher, IInheritXPlanDispatcherTrait,
    SimpleBeneficiary, TokenInfo, PlanConditions
};


// Test function to set up contracts
#[test]
fn test_setup() {
    // Deploy the plan contract
    let contract_class = declare("InheritxPlan").unwrap().contract_class();

    // Create a contract dispatcher
    let (contract_address, _) = contract_class.deploy(@array![]).unwrap();

    contract_address;

    // Create a plan contract dispatcher
    let plan_dispatcher = IInheritXPlanDispatcher { contract_address: contract_address };

    // Now you can use the dispatcher to interact with the contract
    // For example:
    // let plan_id = plan_dispatcher.create_plan(...);
}

