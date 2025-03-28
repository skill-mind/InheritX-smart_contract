use inheritx::interfaces::IInheritX::{
    AssetAllocation, IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait,
};
use inheritx::types::{
    ActivityType, MediaMessage, PlanConditions, PlanOverview, PlanSection, PlanStatus,
    SimpleBeneficiary, TokenInfo,
};
use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
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

// Helper function to setup contract with a test plan
fn setup_with_plan() -> (IInheritXDispatcher, u256, ContractAddress) {
    let inheritx = setup();
    let owner: ContractAddress = contract_address_const::<'owner'>();
    let beneficiary1: ContractAddress = contract_address_const::<'beneficiary1'>();
    let beneficiary2: ContractAddress = contract_address_const::<'beneficiary2'>();
    let inheritx_address: ContractAddress = inheritx.contract_address;

    // Create test plan through contract calls
    let plan_id = inheritx
        .create_inheritance_plan(
            'Test Plan',
            array![
                AssetAllocation { token: owner, amount: 1000, percentage: 50 },
                AssetAllocation { token: owner, amount: 2000, percentage: 50 },
            ],
            'Test Description',
            array![beneficiary1, beneficiary2],
        );

    // To test media messages, we would need to add a function to the contract interface
    // that allows adding media messages with recipients. Since that doesn't exist in your
    // current interface, we'll focus on testing the beneficiaries section which we can
    // properly set up through create_inheritance_plan

    (inheritx, plan_id, inheritx_address)
}

#[test]
fn test_get_basic_information_section() {
    let (inheritx, plan_id, _) = setup_with_plan();
    // storage_write(contract_address, "InheritX::Storage::plans_tokens_count", array[plan_id]!, 2);

    // let token_info: TokenInfo = array![
    // token_address: ContractAddress,
    // symbol,
    // chain,
    // 450_u256,
    // 1000_u256,
    // ];

    // let map_var_name = "InheritxPlan::Storage::plan_tokens";

    // Write to storage for specific plan_id and token_index
    // storage_write(
    //     inheritx_address,
    //     map_var_name,
    //     array![plan_id.low, plan_id.high, token_index.into()], // Key parts
    //     token_info
    // );

    let result: PlanOverview = inheritx.get_plan_section(plan_id, PlanSection::BasicInformation);

    // Verify basic fields
    assert(result.name == 'Test Plan', 'Incorrect plan name');
    assert(result.description == 'Test Description', 'Incorrect description');

    // Verify tokens were loaded
    // assert(result.tokens_transferred.len() == 2, 'Should have 2 tokens');

    // Verify other sections empty
    assert(result.beneficiaries.len() == 0, 'Beneficiaries should be empty');
}

#[test]
fn test_get_beneficiaries_section() {
    let (inheritx, plan_id, _) = setup_with_plan();

    let result = inheritx.get_plan_section(plan_id, PlanSection::Beneficiaries);

    // Verify beneficiaries
    assert(result.beneficiaries.len() == 2, 'Should have 2 beneficiaries');
}

#[test]
#[should_panic(expected: ('Plan does not exist',))]
fn test_get_nonexistent_plan_section() {
    let inheritx = setup();
    inheritx.get_plan_section(999_u256, PlanSection::BasicInformation);
}

#[test]
fn test_empty_sections() {
    let inheritx = setup();
    let owner: ContractAddress = contract_address_const::<'owner'>();

    // Create minimal plan
    let plan_id = inheritx
        .create_inheritance_plan(
            'Empty Plan',
            array![AssetAllocation { token: owner, amount: 1000, percentage: 100 }],
            'Empty Description',
            array![owner],
        );

    // Test all sections
    let basic = inheritx.get_plan_section(plan_id, PlanSection::BasicInformation);
    assert(basic.tokens_transferred.len() == 0, 'Should not have tokens');

    let beneficiaries = inheritx.get_plan_section(plan_id, PlanSection::Beneficiaries);
    assert!(beneficiaries.beneficiaries.len() == 1, "Should have only 1 beneficiary");
}
