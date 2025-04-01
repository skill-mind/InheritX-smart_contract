use recovery_contract::RecoveryContract::{
    ActivityType, IRecoveryDispatcher, IRecoveryDispatcherTrait,
};
use snforge_std::{
    CheatTarget, ContractClassTrait, declare, start_prank, start_warp, stop_prank, stop_warp,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};

// Test constants
const RECOVERY_METHOD: felt252 = 'email';

// Mock user address
fn get_user_address() -> ContractAddress {
    contract_address_const::<'user1'>()
}

// Helper to create UserProfile struct in storage
fn setup_profile(contract: IRecoveryDispatcher, user: ContractAddress) {
    // We need to create a profile for the user first
    // For testing purposes, we can use a custom setup function or prank to set the profile
    // This is a simplified version assuming your contract has a create_profile function
    start_prank(CheatTarget::One(contract.contract_address), user);
    contract.create_profile(user);
    stop_prank(CheatTarget::One(contract.contract_address));
}

// Main setup function
fn setup() -> IRecoveryDispatcher {
    // Declare and deploy the contract
    let contract_class = declare("RecoveryContract").unwrap();
    let constructor_calldata = array![];
    let (contract_address, _) = contract_class.deploy(@constructor_calldata).unwrap();

    // Return the contract dispatcher
    IRecoveryDispatcher { contract_address }
}

#[test]
fn test_generate_recovery_code() {
    // Setup
    let contract = setup();
    let user = get_user_address();

    // Set specific block timestamp for deterministic testing
    let test_timestamp = 1648000000_u64;
    start_warp(CheatTarget::One(contract.contract_address), test_timestamp);

    // Call function
    let recovery_code = contract.generate_recovery_code(user);

    // Since the function uses block timestamp and number which can vary,
    // we can verify that the code is not zero, which would indicate failure
    assert(recovery_code != 0, 'Recovery code should not be zero');

    // Generate code again and ensure it's different (timestamp should change)
    start_warp(CheatTarget::One(contract.contract_address), test_timestamp + 100);
    let new_recovery_code = contract.generate_recovery_code(user);
    assert(recovery_code != new_recovery_code, 'Codes should be different');

    stop_warp(CheatTarget::One(contract.contract_address));
}

#[test]
fn test_initiate_recovery() {
    // Setup
    let contract = setup();
    let user = get_user_address();

    // Create user profile
    setup_profile(contract, user);

    // Set block timestamp
    let test_timestamp = 1648000000_u64;
    start_warp(CheatTarget::One(contract.contract_address), test_timestamp);

    // Call initiate_recovery
    let recovery_code = contract.initiate_recovery(user, RECOVERY_METHOD);

    // Verify code is not zero
    assert(recovery_code != 0, 'Recovery code should not be zero');

    // Verify expiry time is set correctly (timestamp + 3600)
    let expected_expiry = test_timestamp + 3600;

    // We need to manually read from storage since there's no getter in your functions
    // This would require either adding a getter function or using starknet::storage::StorageAccess
    // For this test, we'll verify via the verify_recovery_code function

    let is_valid = contract.verify_recovery_code(user, recovery_code);
    assert(is_valid, 'Code should be valid');

    stop_warp(CheatTarget::One(contract.contract_address));
}

#[test]
#[should_panic(expected: ('User profile does not exist',))]
fn test_initiate_recovery_nonexistent_user() {
    let contract = setup();
    let nonexistent_user = contract_address_const::<'nonexistent'>();

    // This should fail with "User profile does not exist"
    contract.initiate_recovery(nonexistent_user, RECOVERY_METHOD);
}

#[test]
fn test_verify_recovery_code() {
    // Setup
    let contract = setup();
    let user = get_user_address();

    // Create user profile
    setup_profile(contract, user);

    // Set block timestamp
    let test_timestamp = 1648000000_u64;
    start_warp(CheatTarget::One(contract.contract_address), test_timestamp);

    // Initiate recovery
    let recovery_code = contract.initiate_recovery(user, RECOVERY_METHOD);

    // Verify valid code
    let is_valid = contract.verify_recovery_code(user, recovery_code);
    assert(is_valid, 'Code should be valid');

    // Test invalid code
    let invalid_code = recovery_code + 1;
    let is_invalid = contract.verify_recovery_code(user, invalid_code);
    assert(!is_invalid, 'Invalid code should not verify');

    stop_warp(CheatTarget::One(contract.contract_address));
}

#[test]
fn test_verify_recovery_code_expired() {
    // Setup
    let contract = setup();
    let user = get_user_address();

    // Create user profile
    setup_profile(contract, user);

    // Set block timestamp
    let test_timestamp = 1648000000_u64;
    start_warp(CheatTarget::One(contract.contract_address), test_timestamp);

    // Initiate recovery
    let recovery_code = contract.initiate_recovery(user, RECOVERY_METHOD);

    // Warp to time after expiry (3600 seconds + 1)
    start_warp(CheatTarget::One(contract.contract_address), test_timestamp + 3601);

    // Verify expired code
    let is_valid = contract.verify_recovery_code(user, recovery_code);
    assert(!is_valid, 'Expired code should not be valid');

    stop_warp(CheatTarget::One(contract.contract_address));
}

#[test]
fn test_verify_recovery_code_cleanup() {
    // Setup
    let contract = setup();
    let user = get_user_address();

    // Create user profile
    setup_profile(contract, user);

    // Initiate recovery
    let test_timestamp = 1648000000_u64;
    start_warp(CheatTarget::One(contract.contract_address), test_timestamp);
    let recovery_code = contract.initiate_recovery(user, RECOVERY_METHOD);

    // Verify code (this should clear the code and expiry)
    let is_valid = contract.verify_recovery_code(user, recovery_code);
    assert(is_valid, 'Code should be valid initially');

    // Try to verify again - should fail because code was cleared
    let is_still_valid = contract.verify_recovery_code(user, recovery_code);
    assert(!is_still_valid, 'Code should be invalidated after use');

    stop_warp(CheatTarget::One(contract.contract_address));
}
