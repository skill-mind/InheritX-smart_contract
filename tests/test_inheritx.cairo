use inheritx::interfaces::IInheritX::{
    AssetAllocation, IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait,
};
use inheritx::types::{ActivityType, Wallet}; // Added Wallet to support wallet tests
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
        let (dispatcher, contract_address) = setup();

        // Ensure dispatcher methods exist
        let deployed = dispatcher.test_deployment();

        assert(deployed, 'deployment failed');
    }

    #[test]
    fn test_create_inheritance_plan() {
        let (dispatcher, contract_address) = setup();
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
        let plan_id = dispatcher
            .create_inheritance_plan(plan_name, assets, description, pick_beneficiaries);

        // assert(plan_id == 1, 'create_inheritance_plan failed');
        let plan = dispatcher.get_inheritance_plan(plan_id);
        assert(plan.is_active, 'is_active mismatch');
        assert(!plan.is_claimed, 'is_claimed mismatch');
        assert(plan.total_value == 2000, 'total_value mismatch');
    }

    #[test]
    #[should_panic(expected: ('No assets specified',))]
    fn test_create_inheritance_plan_no_assets() {
        let (dispatcher, contract_address) = setup();
        let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
        let pick_beneficiaries: Array<ContractAddress> = array![benefactor];
        let plan_name: felt252 = 'plan1';
        let description: felt252 = 'plan_desc';

        // Ensure the caller is the admin
        // cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

        // Test with no assets
        let assets: Array<AssetAllocation> = array![];
        dispatcher.create_inheritance_plan(plan_name, assets, description, pick_beneficiaries);
    }

    #[test]
    #[should_panic(expected: ('No beneficiaries specified',))]
    fn test_create_inheritance_plan_no_beneficiaries() {
        let (dispatcher, contract_address) = setup();
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


// Wallet Management tests

#[test]
fn test_add_first_wallet() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();
    let wallet_addr = contract_address_const::<'wallet1'>();
    let wallet_type = 'personal';
    cheat_caller_address(inheritX.contract_address, user, CheatSpan::Indefinite);
    let success = inheritX.add_wallet(wallet_addr, wallet_type);
    assert(success, 'err1');
    let primary_wallet = inheritX.get_primary_wallet(user);
    assert(primary_wallet == wallet_addr, 'err2');
    let wallets = inheritX.get_user_wallets(user);
    assert(wallets.len() == 1, 'err3');
    let wallet = wallets.at(0);
    assert(*wallet.address == wallet_addr, 'err4');
    assert(*wallet.is_primary, 'err5');
    assert(*wallet.wallet_type == wallet_type, 'err6');
}

#[test]
fn test_add_multiple_wallets() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();
    let wallet1 = contract_address_const::<'wallet1'>();
    let wallet2 = contract_address_const::<'wallet2'>();
    let wallet3 = contract_address_const::<'wallet3'>();
    let wallet_type = 'personal';
    cheat_caller_address(inheritX.contract_address, user, CheatSpan::Indefinite);
    inheritX.add_wallet(wallet1, wallet_type);
    inheritX.add_wallet(wallet2, wallet_type);
    inheritX.add_wallet(wallet3, wallet_type);
    let wallets = inheritX.get_user_wallets(user);
    assert(wallets.len() == 3, 'err1');
    let primary_wallet = inheritX.get_primary_wallet(user);
    assert(primary_wallet == wallet1, 'err2');
}

#[test]
fn test_set_primary_wallet() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();
    let wallet1 = contract_address_const::<'wallet1'>();
    let wallet2 = contract_address_const::<'wallet2'>();
    let type_personal = 'personal';
    let type_inheritance = 'inheritance';
    cheat_caller_address(inheritX.contract_address, user, CheatSpan::Indefinite);
    inheritX.add_wallet(wallet1, type_personal);
    inheritX.add_wallet(wallet2, type_inheritance);
    let success = inheritX.set_primary_wallet(wallet2);
    assert(success, 'err_set');
    let primary_wallet = inheritX.get_primary_wallet(user);
    assert(primary_wallet == wallet2, 'err2');
    let wallets = inheritX.get_user_wallets(user);
    let wallet = wallets.at(0);
    assert(*wallet.is_primary == false, 'err3');
    assert(*wallets.at(1).is_primary, 'err4');
    assert(*wallet.wallet_type == type_personal, 'err5');
    assert(*wallets.at(1).wallet_type == type_inheritance, 'err6');
}

#[test]
#[should_panic(expected: ('Wallet already exists',))]
fn test_add_duplicate_wallet() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();
    let wallet_addr = contract_address_const::<'wallet1'>();
    let wallet_type = 'personal';
    cheat_caller_address(inheritX.contract_address, user, CheatSpan::Indefinite);
    inheritX.add_wallet(wallet_addr, wallet_type);
    inheritX.add_wallet(wallet_addr, wallet_type);
}

#[test]
#[should_panic(expected: ('Wallet not found',))]
fn test_set_primary_non_existent_wallet() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();
    let non_existent_wallet = contract_address_const::<'non_existent'>();
    cheat_caller_address(inheritX.contract_address, user, CheatSpan::Indefinite);
    inheritX.set_primary_wallet(non_existent_wallet);
}

#[test]
fn test_wallet_types() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();
    let wallet1 = contract_address_const::<'wallet1'>();
    let wallet2 = contract_address_const::<'wallet2'>();
    let type_personal = 'personal';
    let type_inheritance = 'inheritance';
    cheat_caller_address(inheritX.contract_address, user, CheatSpan::Indefinite);
    inheritX.add_wallet(wallet1, type_personal);
    inheritX.add_wallet(wallet2, type_inheritance);
    let wallets = inheritX.get_user_wallets(user);
    assert(wallets.len() == 2, 'err1');
    assert(*wallets.at(0).wallet_type == type_personal, 'err2');
    assert(*wallets.at(1).wallet_type == type_inheritance, 'err3');
}