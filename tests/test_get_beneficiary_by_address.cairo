use inheritx::InheritX::InheritX;
use inheritx::interfaces::IInheritX::{IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait};
use inheritx::types::SimpleBeneficiary;
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

    (contract_address)
}

// Helper function to create a claim and return the claim_id
fn create_test_claim(
    dispatcher: IInheritXDispatcher,
    benefactor: ContractAddress,
    beneficiary: ContractAddress,
    name: felt252,
    email: felt252,
    amount: u256,
    claim_code: u256,
) -> u256 {
    // Set the caller to benefactor
    cheat_caller_address(dispatcher.contract_address, benefactor, CheatSpan::Indefinite);

    // Create the claim
    let claim_id = dispatcher
        .create_claim(name, email, beneficiary, 'Test personal message', amount, claim_code);

    claim_id
}

#[test]
fn test_get_beneficiary_exists() {
    // Setup the contract
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };

    // Create test addresses
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();

    // Test input values
    let name: felt252 = 'John';
    let email: felt252 = 'john@example.com';
    let amount: u256 = 1000;
    let claim_code: u256 = 12345;

    // Create a claim
    let claim_id = create_test_claim(
        dispatcher, benefactor, beneficiary, name, email, amount, claim_code,
    );

    // Retrieve the beneficiary by address
    let found_beneficiary = dispatcher.get_beneficiary_by_address(beneficiary);

    // Verify beneficiary details match
    assert(found_beneficiary.id == claim_id, 'Found wrong beneficiary ID');
    assert(found_beneficiary.name == name, 'Name mismatch');
    assert(found_beneficiary.email == email, 'Email mismatch');
    assert(found_beneficiary.wallet_address == beneficiary, 'Address mismatch');
    assert(found_beneficiary.amount == amount, 'Amount mismatch');
    assert(found_beneficiary.benefactor == benefactor, 'Benefactor mismatch');
    assert(found_beneficiary.claim_status == false, 'Claim status mismatch');
}

#[test]
fn test_get_beneficiary_not_exists() {
    // Setup the contract
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };

    // Create test addresses
    let nonexistent_address: ContractAddress = contract_address_const::<'nonexistent'>();

    // Try to retrieve a nonexistent beneficiary
    let found_beneficiary = dispatcher.get_beneficiary_by_address(nonexistent_address);

    // Verify we got a default beneficiary (all values zeroed)
    assert(found_beneficiary.id == 0, 'ID should be 0');
    assert(found_beneficiary.name == 0, 'Name should be 0');
    assert(found_beneficiary.email == 0, 'Email should be 0');

    // Get zero address to compare
    let zero_address: ContractAddress = 0.try_into().unwrap();
    assert(found_beneficiary.wallet_address == zero_address, 'Address should be zero');
    assert(found_beneficiary.benefactor == zero_address, 'Benefactor should be zero');

    assert(found_beneficiary.amount == 0, 'Amount should be 0');
    assert(found_beneficiary.code == 0, 'Code should be 0');
    assert(found_beneficiary.claim_status == false, 'Claim status should be false');
}

#[test]
fn test_get_beneficiary_multiple_entries() {
    // Setup the contract
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };

    // Create test addresses
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary1: ContractAddress = contract_address_const::<'beneficiary1'>();
    let beneficiary2: ContractAddress = contract_address_const::<'beneficiary2'>();
    let beneficiary3: ContractAddress = contract_address_const::<'beneficiary3'>();

    // Create multiple claims with different beneficiaries
    let claim_id1 = create_test_claim(
        dispatcher, benefactor, beneficiary1, 'Alice', 'alice@example.com', 1000, 11111,
    );

    let claim_id2 = create_test_claim(
        dispatcher, benefactor, beneficiary2, 'Bob', 'bob@example.com', 2000, 22222,
    );

    let claim_id3 = create_test_claim(
        dispatcher, benefactor, beneficiary3, 'Charlie', 'charlie@example.com', 3000, 33333,
    );

    // Find the second beneficiary
    let found_beneficiary = dispatcher.get_beneficiary_by_address(beneficiary2);

    // Verify we found the correct beneficiary
    assert(found_beneficiary.id == claim_id2, 'Found wrong beneficiary ID');
    assert(found_beneficiary.name == 'Bob', 'Name mismatch');
    assert(found_beneficiary.email == 'bob@example.com', 'Email mismatch');
    assert(found_beneficiary.wallet_address == beneficiary2, 'Address mismatch');
    assert(found_beneficiary.amount == 2000, 'Amount mismatch');
    assert(found_beneficiary.code == 22222, 'Code mismatch');
}

#[test]
fn test_get_beneficiary_after_claim() {
    // Setup the contract
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };

    // Create test addresses
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();

    // Test input values
    let name: felt252 = 'David';
    let email: felt252 = 'david@example.com';
    let amount: u256 = 5000;
    let claim_code: u256 = 54321;

    // Create a claim
    let claim_id = create_test_claim(
        dispatcher, benefactor, beneficiary, name, email, amount, claim_code,
    );

    // Change the caller to the beneficiary and collect the claim
    cheat_caller_address(dispatcher.contract_address, beneficiary, CheatSpan::Indefinite);
    let success = dispatcher.collect_claim(claim_id, beneficiary, claim_code);
    assert(success, 'Claim collection failed');

    // Retrieve the beneficiary and check the claim status
    let found_beneficiary = dispatcher.get_beneficiary_by_address(beneficiary);

    // Verify the claim status has been updated
    assert(found_beneficiary.claim_status == true, 'Claim status should be true');
    assert(found_beneficiary.id == claim_id, 'Found wrong beneficiary ID');
    assert(found_beneficiary.name == name, 'Name mismatch');
}
