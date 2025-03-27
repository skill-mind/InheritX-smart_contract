use inheritx::interfaces::IInheritX::{IInheritXDispatcher, IInheritXDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::contract_address_const;

// Helper function to set up the contract for testing
fn setup() -> IInheritXDispatcher {
    let contract_class = declare("InheritX").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IInheritXDispatcher { contract_address }
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