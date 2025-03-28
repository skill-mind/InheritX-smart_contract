// // Import the contract modules
use inheritx::interfaces::IInheritX::{
    AssetAllocation, IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait,
};
use inheritx::types::ActivityType;
use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, cheat_block_timestamp, declare};
use starknet::ContractAddress;
use starknet::class_hash::ClassHash;
use starknet::contract_address::contract_address_const;
use starknet::testing::{set_caller_address, set_contract_address};

fn setup() -> ContractAddress {
    let declare_result = declare("InheritX");
    assert(declare_result.is_ok(), 'Contract declaration failed');

    let contract_class = declare_result.unwrap().contract_class();
    let mut calldata = array![];

    let deploy_result = contract_class.deploy(@calldata);
    assert(deploy_result.is_ok(), 'Contract deployment failed');

    let (contract_address, _) = deploy_result.unwrap();

    (contract_address)
}

fn setup_plan() -> (ContractAddress, u256) {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
    let pick_beneficiaries: Array<ContractAddress> = array![beneficiary];
    let assets: Array<AssetAllocation> = array![
        AssetAllocation { token: benefactor, amount: 1000, percentage: 50 },
        AssetAllocation { token: beneficiary, amount: 1000, percentage: 50 },
    ];
    let plan_name: felt252 = 'plan1';
    let description: felt252 = 'plan_desc';

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

    // Call create_inheritance_plan
    let plan_id = dispatcher.create_inheritance_plan(plan_name, assets, description, pick_beneficiaries);

    (contract_address, plan_id)
}

#[test]
fn test_can_execute_plan_success(){
    let (contract_address, plan_id) = setup_plan();
    let dispatcher = IInheritXDispatcher { contract_address };
    cheat_block_timestamp(contract_address, 1001, CheatSpan::TargetCalls(1));
    let result = dispatcher.can_execute_plan(plan_id);
    assert(result == true, 'should return success');

}

#[test]
#[should_panic(expected: 'Invalid plan ID')]
fn test_can_execute_plan_invalid_id() {
    let (contract_address, plan_id) = setup_plan();
    let dispatcher = IInheritXDispatcher { contract_address };
    cheat_block_timestamp(contract_address, 1001, CheatSpan::TargetCalls(1));
    let result = dispatcher.can_execute_plan(plan_id+1);
    assert(result == false, 'plan ID should be invalid');
}

// #[test]
// #[should_panic(expected: 'Plan is not active')]
// fn test_can_execute_plan_inactive_plan(){
//     let (contract_address, plan_id) = setup_plan();
//     let dispatcher = IInheritXDispatcher { contract_address };
//     dispatcher.set_plan_status(plan_id, false);
//     cheat_block_timestamp(contract_address, 1001, CheatSpan::TargetCalls(1));
//     let result = dispatcher.can_execute_plan(plan_id);
//     assert(result == false, 'plan ID should be invalid');

// }

#[test]
#[should_panic(expected:'Transfer date not reached')]
fn test_can_execute_plan_date_not_reached(){
    let (contract_address, plan_id) = setup_plan();
    let dispatcher = IInheritXDispatcher { contract_address };
    dispatcher.set_plan_transfer_date(plan_id, 2000);
    cheat_block_timestamp(contract_address, 1001, CheatSpan::TargetCalls(1));
    let result = dispatcher.can_execute_plan(plan_id);
    assert(result == false, 'date should not be reached');
}

#[test]
#[should_panic(expected:'Inactivity period not met')]
fn test_can_execute_plan_period_not_met(){
    let (contract_address, plan_id) = setup_plan();
    let dispatcher = IInheritXDispatcher { contract_address };
    cheat_block_timestamp(contract_address, 900, CheatSpan::TargetCalls(1));
    let result = dispatcher.can_execute_plan(plan_id);
    assert(result == false, 'date should not be reached');
}

// #[test]
// #[should_panic(expected:'Not enough approvals')]
// fn test_can_execute_plan_not_approved(){

// }

