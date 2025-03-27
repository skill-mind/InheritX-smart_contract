use inheritx::interfaces::IInheritX::{IInheritXDispatcher, IInheritXDispatcherTrait};
use inheritx::types::ActivityType;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, store, map_entry_address};
use starknet::contract_address_const;

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
fn test_verify_code() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();
    let code: felt252 = 12345;

    // Initially, the user should not be verified
    let is_verified = inheritX.is_verified(user);
    assert(is_verified == false, 'User not be verified initially');

    // Simulate setting the expected code using store cheatcode
    store(
        inheritX.contract_address,
        map_entry_address(selector!("expected_code"), array![user.into()].span()),
        array![code].span(),
    );

    // Call verify_code with the correct code
    let verification_result = inheritX.verify_code(user, code);
    assert(verification_result == true, 'Ver should succeed correct code');

    // User should now be verified
    let is_verified = inheritX.is_verified(user);
    assert(is_verified == true, 'User should now be verified');
}

#[test]
fn test_verify_code_incorrect_code() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();
    let correct_code: felt252 = 12345;
    let incorrect_code: felt252 = 54321;

    // Initially, the user should not be verified
    let is_verified = inheritX.is_verified(user);
    assert(is_verified == false, 'User not be verified initially');

    // Cheat: Set the expected code for the user
    // inheritX.expected_code.write(user, correct_code);

    // Call verify_code with the incorrect code
    let verification_result = inheritX.verify_code(user, incorrect_code);
    assert(verification_result == false, 'Verification fail incorrect');

    // User should still not be verified
    let is_verified = inheritX.is_verified(user);
    assert(is_verified == false, 'User still not be verified');
}
