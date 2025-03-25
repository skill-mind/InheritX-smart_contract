use inheritx::interfaces::IInheritX::{
    AssetAllocation, IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait,
};
use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
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

    contract_address
}

#[test]
fn test_initial_data() {
    let contract_address = setup();

    let dispatcher = IInheritXDispatcher { contract_address };

    // Ensure dispatcher methods exist
    let deployed = dispatcher.test_deployment();

    assert(deployed, 'deployment failed');
}

#[test]
fn test_create_inheritance_plan() {
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
    let plan_id = dispatcher
        .create_inheritance_plan(plan_name, assets, description, pick_beneficiaries);

    // assert(plan_id == 1, 'create_inheritance_plan failed');
    let plan = dispatcher.get_inheritance_plan(plan_id);
    assert(plan.owner == benefactor, 'owner mismatch');
    assert(plan.is_active, 'is_active mismatch');
    assert(!plan.is_claimed, 'is_claimed mismatch');
    assert(plan.total_value == 2000, 'total_value mismatch');
}

#[test]
#[should_panic(expected: ('No assets specified',))]
fn test_create_inheritance_plan_no_assets() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let pick_beneficiaries: Array<ContractAddress> = array![benefactor];
    let plan_name: felt252 = 'plan1';
    let description: felt252 = 'plan_desc';

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

    // Test with no assets
    let assets: Array<AssetAllocation> = array![];
    dispatcher.create_inheritance_plan(plan_name, assets, description, pick_beneficiaries);
}

#[test]
#[should_panic(expected: ('No beneficiaries specified',))]
fn test_create_inheritance_plan_no_beneficiaries() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
    let pick_beneficiaries: Array<ContractAddress> = array![];
    let plan_name: felt252 = 'plan1';
    let description: felt252 = 'plan_desc';

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

    let assets: Array<AssetAllocation> = array![
        AssetAllocation { token: benefactor, amount: 1000, percentage: 50 },
        AssetAllocation { token: beneficiary, amount: 1000, percentage: 50 },
    ];
    dispatcher.create_inheritance_plan(plan_name, assets, description, pick_beneficiaries);
}
