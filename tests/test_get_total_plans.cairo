use inheritx::interfaces::IInheritX::{IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use starknet::contract_address::contract_address_const;
use snforge_std::{cheat_caller_address, CheatSpan};

fn setup() -> ContractAddress {
    let declare_result = declare("InheritX");
    assert(declare_result.is_ok(), 'Contract declaration failed');

    let contract_class = declare_result.unwrap().contract_class();
    let mut calldata = array![];

    let deploy_result = contract_class.deploy(@calldata);
    assert(deploy_result.is_ok(), 'Contract deployment failed');

    let (contract_address, _) = deploy_result.unwrap();

    contract_address
}

#[test]
fn test_get_total_plans_initial() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };

    // Ensure the initial total plans count is 0
    let total_plans = dispatcher.get_total_plans();
    assert(total_plans == 0, 'Initial total plans should be 0');
}

#[test]
fn test_get_total_plans_after_creation() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();

    // Test input values
    let name: felt252 = 'John';
    let email: felt252 = 'John@yahoo.com'; 
    let personal_message = 'i love you my son';
    let claim_code = 2563;

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

    // Call create_claim to create a new plan
    let claim_id = dispatcher.create_claim(name, email, beneficiary, personal_message, 1000, claim_code);

    // Validate that the claim ID is correctly incremented
    assert(claim_id == 0, 'claim ID should start from 0');

    // Check the total plans count after creating a new plan
    let total_plans = dispatcher.get_total_plans();
    assert(total_plans == 1, 'Total plans should be 1');
}