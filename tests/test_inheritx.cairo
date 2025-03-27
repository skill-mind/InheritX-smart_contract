use inheritx::interfaces::IInheritX::{IInheritXDispatcher, IInheritXDispatcherTrait};
use inheritx::types::ActivityType;
use starknet::ContractAddress;
use snforge_std::{ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare, CheatSpan};
use starknet::contract_address_const;

/// Setup function to deploy the contract and return the dispatcher.
fn setup() -> IInheritXDispatcher {
    let contract_class = declare("InheritX").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IInheritXDispatcher { contract_address }
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

#[test]
fn test_get_beneficiary_by_address() {
    let inheritX = setup();
    let beneficiary_address = contract_address_const::<'beneficiary'>();
    let non_existent_address = contract_address_const::<'non_existent'>();
    
    // Create a claim to add a beneficiary
    let name = 'John Doe';
    let email = 'john@example.com';
    let personal_message = 'Take care of yourself';
    let amount = 1000_u256;
    let claim_code = 12345_u256;
    
    // Record the claim and get the ID
    let inheritance_id = inheritX.create_claim(
        name, email, beneficiary_address, personal_message, amount, claim_code
    );
    
    // Test retrieving the beneficiary by address
    let found_beneficiary = inheritX.get_beneficiary_by_address(beneficiary_address);
    
    // Verify all fields match what we created
    assert(found_beneficiary.id == inheritance_id, 'Wrong beneficiary ID');
    assert(found_beneficiary.name == name, 'Wrong beneficiary name');
    assert(found_beneficiary.email == email, 'Wrong beneficiary email');
    assert(found_beneficiary.wallet_address == beneficiary_address, 'Wrong wallet address');
    assert(found_beneficiary.personal_message == personal_message, 'Wrong personal message');
    assert(found_beneficiary.amount == amount, 'Wrong amount');
    assert(found_beneficiary.code == claim_code, 'Wrong claim code');
    assert(found_beneficiary.claim_status == false, 'Wrong claim status');
    
    // Test with a non-existent address
    let not_found_beneficiary = inheritX.get_beneficiary_by_address(non_existent_address);
    
    // Verify a default zero beneficiary is returned
    assert(not_found_beneficiary.id == 0, 'Should have zero ID');
    assert(not_found_beneficiary.name == 0, 'Should have zero name');
    assert(not_found_beneficiary.email == 0, 'Should have zero email');
    assert(not_found_beneficiary.amount == 0, 'Should have zero amount');
    assert(not_found_beneficiary.claim_status == false, 'Should be unclaimed');
}
