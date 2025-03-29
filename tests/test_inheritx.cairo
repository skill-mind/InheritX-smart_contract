use inheritx::interfaces::IInheritX::{
    AssetAllocation, IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait,
};
use inheritx::types::ActivityType;
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_block_timestamp, cheat_caller_address,
    declare,
};
use starknet::ContractAddress;
use starknet::class_hash::ClassHash;
use starknet::contract_address::contract_address_const;
use starknet::testing::{set_caller_address, set_contract_address};


fn setup() -> IInheritXDispatcher {
    let contract_class = declare("InheritX").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IInheritXDispatcher { contract_address }
}

fn setup_plan() -> (IInheritXDispatcher, u256) {
    let dispatcher = setup();
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
    cheat_caller_address(dispatcher.contract_address, benefactor, CheatSpan::Indefinite);

    // Call create_inheritance_plan
    let plan_id = dispatcher
        .create_inheritance_plan(plan_name, assets, description, pick_beneficiaries);

    (dispatcher, plan_id)
}

#[test]
fn test_can_execute_plan_success() {
    let (dispatcher, plan_id) = setup_plan();
    cheat_block_timestamp(dispatcher.contract_address, 1001, CheatSpan::TargetCalls(1));
    let result = dispatcher.can_execute_plan(plan_id);
    assert(result == true, 'should return success');
}

#[test]
#[should_panic(expected: 'Invalid plan ID')]
fn test_can_execute_plan_invalid_id() {
    let (dispatcher, plan_id) = setup_plan();
    cheat_block_timestamp(dispatcher.contract_address, 1001, CheatSpan::TargetCalls(1));
    let result = dispatcher.can_execute_plan(plan_id + 1);
    assert(result == false, 'plan ID should be invalid');
}

// #[test]
// #[should_panic(expected: 'Plan is not active')]
// fn test_can_execute_plan_inactive_plan(){
//     let (dispatcher, plan_id) = setup_plan();
//     dispatcher.set_plan_status(plan_id, false);
//     cheat_block_timestamp(dispatcher.contract_address, 1001, CheatSpan::TargetCalls(1));
//     let result = dispatcher.can_execute_plan(plan_id);
//     assert(result == false, 'plan ID should be invalid');

// }

#[test]
#[should_panic(expected: 'Transfer date not reached')]
fn test_can_execute_plan_date_not_reached() {
    let (dispatcher, plan_id) = setup_plan();
    dispatcher.set_plan_transfer_date(plan_id, 2000);
    cheat_block_timestamp(dispatcher.contract_address, 1001, CheatSpan::TargetCalls(1));
    let result = dispatcher.can_execute_plan(plan_id);
    assert(result == false, 'date should not be reached');
}

#[test]
#[should_panic(expected: 'Inactivity period not met')]
fn test_can_execute_plan_period_not_met() {
    let (dispatcher, plan_id) = setup_plan();
    cheat_block_timestamp(dispatcher.contract_address, 900, CheatSpan::TargetCalls(1));
    let result = dispatcher.can_execute_plan(plan_id);
    assert(result == false, 'date should not be reached');
}
// #[test]
// #[should_panic(expected:'Not enough approvals')]
// fn test_can_execute_plan_not_approved(){

// }

#[test]
fn test_initial_data() {
    let inheritX = setup();

    // Ensure dispatcher methods exist
    let deployed = inheritX.test_deployment();

    assert(deployed, 'deployment failed');
}

#[test]
fn test_create_inheritance_plan() {
    let inheritX = setup();
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
    // cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

    // Call create_inheritance_plan
    let plan_id = inheritX
        .create_inheritance_plan(plan_name, assets, description, pick_beneficiaries);

    // assert(plan_id == 1, 'create_inheritance_plan failed');
    let plan = inheritX.get_inheritance_plan(plan_id);
    assert(plan.is_active, 'is_active mismatch');
    assert(!plan.is_claimed, 'is_claimed mismatch');
    assert(plan.total_value == 2000, 'total_value mismatch');
}

#[test]
#[should_panic(expected: ('No assets specified',))]
fn test_create_inheritance_plan_no_assets() {
    let inheritX = setup();
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let pick_beneficiaries: Array<ContractAddress> = array![benefactor];
    let plan_name: felt252 = 'plan1';
    let description: felt252 = 'plan_desc';

    // Ensure the caller is the admin
    // cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

    // Test with no assets
    let assets: Array<AssetAllocation> = array![];
    inheritX.create_inheritance_plan(plan_name, assets, description, pick_beneficiaries);
}

#[test]
#[should_panic(expected: ('No beneficiaries specified',))]
fn test_create_inheritance_plan_no_beneficiaries() {
    let inheritX = setup();
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
    let pick_beneficiaries: Array<ContractAddress> = array![];
    let plan_name: felt252 = 'plan1';
    let description: felt252 = 'plan_desc';

    // Ensure the caller is the admin
    // cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

    let assets: Array<AssetAllocation> = array![
        AssetAllocation { token: benefactor, amount: 1000, percentage: 50 },
        AssetAllocation { token: beneficiary, amount: 1000, percentage: 50 },
    ];
    inheritX.create_inheritance_plan(plan_name, assets, description, pick_beneficiaries);
}

#[test]
fn test_get_activity_history_empty() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();

    // Check initial activity history length
    let history_length = inheritX.get_activity_history_length(user);
    assert(history_length == 0, 'Initial history should be empty');

    // Try to retrieve history
    let history = inheritX.get_activity_history(user, 0, 10);
    assert(history.len() == 0, 'History should be empty');
}

#[test]
fn test_get_activity_history_pagination() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();

    // Record multiple activities
    let _activity1_id = inheritX
        .record_user_activity(
            user, ActivityType::Login, 'First login', '192.168.1.1', 'Desktop Chrome',
        );

    let _activity2_id = inheritX
        .record_user_activity(
            user,
            ActivityType::ProfileUpdate,
            'Profile details updated',
            '192.168.1.2',
            'Mobile Safari',
        );

    let _activity3_id = inheritX
        .record_user_activity(
            user,
            ActivityType::WalletConnection,
            'Wallet connected',
            '192.168.1.3',
            'Mobile Android',
        );

    // Check total history length
    let history_length = inheritX.get_activity_history_length(user);
    assert(history_length == 3, 'Incorrect history length');

    // Test first page (2 records)
    let first_page = inheritX.get_activity_history(user, 0, 2);
    assert(first_page.len() == 2, 'should have 2 records');

    // Test second page (1 record)
    let second_page = inheritX.get_activity_history(user, 2, 2);
    assert(second_page.len() == 1, 'should have 1 record');
}

#[test]
#[should_panic(expected: ('Page size must be positive',))]
fn test_get_activity_history_invalid_page_size() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();

    // Should panic with zero page size
    inheritX.get_activity_history(user, 0, 0);
}
