use inheritx::interfaces::IInheritX::{IInheritXDispatcher, IInheritXDispatcherTrait};
use inheritx::types::ActivityType;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
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
fn test_add_media_message() {
    let inheritX = setup();

    // Setup test parameters
    let plan_id = 1_u256;
    let media_type = 0_felt252;  // Example: 0 for image
    let media_content = 123456_felt252;  // Example: IPFS hash or URL as felt252

    // Add a media message to a plan
    inheritX.add_media_message(plan_id, media_type, media_content);

    // Verify the media message was added
    let current_count = inheritX.media_message_count(plan_id);
    assert(current_count == 1_u256, 'Media message count mismatch');

    let stored_message = inheritX.media_messages(plan_id, 0_u256);
    assert(stored_message.plan_id == plan_id, 'Plan ID mismatch');
    assert(stored_message.media_type == media_type, 'Media type mismatch');
    assert(stored_message.media_content == media_content, 'Media content mismatch');
}

/// Test adding a wallet for the first time
#[test]
fn test_add_first_wallet() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();
    let wallet = contract_address_const::<'wallet1'>();

    // Add the first wallet
    let result = inheritX.add_wallet(wallet, 'personal');
    assert(result == true, 'Failed to add first wallet');

    // Check primary wallet
    let primary_wallet = inheritX.get_primary_wallet(user);
    assert(primary_wallet == wallet, 'First wallet should be primary');

    // Retrieve user wallets
    let user_wallets = inheritX.get_user_wallets(user);
    assert(user_wallets.len() == 1, 'Should have one wallet');
    assert(user_wallets.at(0).address == wallet, 'Wallet address mismatch');
    assert(user_wallets.at(0).is_primary == true, 'First wallet should be primary');
}

/// Test adding multiple wallets
#[test]
fn test_add_multiple_wallets() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();
    let wallet1 = contract_address_const::<'wallet1'>();
    let wallet2 = contract_address_const::<'wallet2'>();
    let wallet3 = contract_address_const::<'wallet3'>();

    // Add first wallet
    let result1 = inheritX.add_wallet(wallet1, 'personal');
    assert(result1 == true, 'Failed to add first wallet');

    // Add second wallet
    let result2 = inheritX.add_wallet(wallet2, 'inheritance');
    assert(result2 == true, 'Failed to add second wallet');

    // Add third wallet
    let result3 = inheritX.add_wallet(wallet3, 'business');
    assert(result3 == true, 'Failed to add third wallet');

    // Retrieve user wallets
    let user_wallets = inheritX.get_user_wallets(user);
    assert(user_wallets.len() == 3, 'Should have three wallets');
}

/// Test setting a different primary wallet
#[test]
fn test_set_primary_wallet() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();
    let wallet1 = contract_address_const::<'wallet1'>();
    let wallet2 = contract_address_const::<'wallet2'>();

    // Add first wallet
    inheritX.add_wallet(wallet1, 'personal');

    // Add second wallet
    inheritX.add_wallet(wallet2, 'inheritance');

    // Set second wallet as primary
    let set_result = inheritX.set_primary_wallet(wallet2);
    assert(set_result == true, 'Failed to set new primary wallet');

    // Check primary wallet
    let primary_wallet = inheritX.get_primary_wallet(user);
    assert(primary_wallet == wallet2, 'Second wallet should be primary');

    // Verify wallet states
    let user_wallets = inheritX.get_user_wallets(user);
    let mut wallet1_found = false;
    let mut wallet2_found = false;

    // Check wallet primary status
    for wallet in user_wallets.iter() {
        if wallet.address == wallet1 {
            wallet1_found = true;
            assert(wallet.is_primary == false, 'First wallet should not be primary');
        }
        if wallet.address == wallet2 {
            wallet2_found = true;
            assert(wallet.is_primary == true, 'Second wallet should be primary');
        }
    }

    assert(wallet1_found && wallet2_found, 'Both wallets should exist');
}

/// Test adding duplicate wallet
#[test]
#[should_panic(expected: ('Wallet already exists',))]
fn test_add_duplicate_wallet() {
    let inheritX = setup();
    let wallet = contract_address_const::<'wallet1'>();

    // Add first wallet
    inheritX.add_wallet(wallet, 'personal');

    // Try to add the same wallet again (should panic)
    inheritX.add_wallet(wallet, 'inheritance');
}

/// Test setting primary wallet for non-existent wallet
#[test]
#[should_panic(expected: ('Wallet not found',))]
fn test_set_primary_non_existent_wallet() {
    let inheritX = setup();
    let wallet = contract_address_const::<'wallet1'>();

    // Try to set primary for a wallet that doesn't exist
    inheritX.set_primary_wallet(wallet);
}

/// Test wallet wallet types
#[test]
fn test_wallet_types() {
    let inheritX = setup();
    let user = contract_address_const::<'user'>();
    let personal_wallet = contract_address_const::<'personal'>();
    let inheritance_wallet = contract_address_const::<'inheritance'>();
    let business_wallet = contract_address_const::<'business'>();

    // Add wallets with different types
    inheritX.add_wallet(personal_wallet, 'personal');
    inheritX.add_wallet(inheritance_wallet, 'inheritance');
    inheritX.add_wallet(business_wallet, 'business');

    // Retrieve user wallets
    let user_wallets = inheritX.get_user_wallets(user);
    assert(user_wallets.len() == 3, 'Should have three wallets');

    // Verify wallet types
    let mut personal_found = false;
    let mut inheritance_found = false;
    let mut business_found = false;

    for wallet in user_wallets.iter() {
        if wallet.wallet_type == 'personal' {
            personal_found = true;
        }
        if wallet.wallet_type == 'inheritance' {
            inheritance_found = true;
        }
        if wallet.wallet_type == 'business' {
            business_found = true;
        }
    }

    assert(personal_found, 'Personal wallet not found');
    assert(inheritance_found, 'Inheritance wallet not found');
    assert(business_found, 'Business wallet not found');
}