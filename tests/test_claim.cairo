// Import the contract modules
use inheritx::interfaces::IInheritX::{
    AssetAllocation, IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait,
};
use inheritx::types::ActivityType;
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

#[test]
fn test_initial_data() {
    let contract_address = setup();

    let dispatcher = IInheritXDispatcher { contract_address };

    // Ensure dispatcher methods exist
    let deployed = dispatcher.test_deployment();

    assert(deployed == true, 'deployment failed');
}


#[test]
fn test_create_claim() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();

    // Test input values
    let name: felt252 = 'John';
    let email: felt252 = 'John@yahoo.com';
    let personal_message = 'i love you my son';
    let claim_code = 2563;

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

    // Call create_claim
    let claim_id = dispatcher
        .create_claim(name, email, beneficiary, personal_message, 1000, claim_code);

    // Validate that the claim ID is correctly incremented
    assert(claim_id == 0, 'claim ID should start from 0');

    // Retrieve the claim to verify it was stored correctly
    let claim = dispatcher.retrieve_claim(claim_id);
    assert(claim.id == claim_id, 'claim ID mismatch');
    assert(claim.name == name, 'claim title mismatch');
    assert(claim.personal_message == personal_message, 'claim description mismatch');
    assert(claim.code == claim_code, 'claim price mismatch');
    assert(claim.wallet_address == beneficiary, 'cbenificiary address mismatch');
    assert(claim.email == email, 'claim email mismatch');
    assert(claim.benefactor == benefactor, 'benefactor address mismatch');
}


#[test]
fn test_collect_claim() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();

    // Test input values
    let name: felt252 = 'John';
    let email: felt252 = 'John@yahoo.com';
    let personal_message = 'i love you my son';
    let claim_code = 2563;

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

    // Call create_claim
    let claim_id = dispatcher
        .create_claim(name, email, beneficiary, personal_message, 1000, claim_code);

    // Validate that the claim ID is correctly incremented
    assert(claim_id == 0, 'claim ID should start from 0');
    cheat_caller_address(contract_address, beneficiary, CheatSpan::Indefinite);

    let success = dispatcher.collect_claim(0, beneficiary, 2563);

    assert(success, 'Claim unsuccessful');
}

#[test]
#[should_panic(expected: 'Not your claim')]
fn test_collect_claim_with_wrong_address() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
    let malicious: ContractAddress = contract_address_const::<'malicious'>();

    // Test input values
    let name: felt252 = 'John';
    let email: felt252 = 'John@yahoo.com';
    let personal_message = 'i love you my son';
    let claim_code = 2563;

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

    // Call create_claim
    let claim_id = dispatcher
        .create_claim(name, email, beneficiary, personal_message, 1000, claim_code);

    // Validate that the claim ID is correctly incremented
    assert(claim_id == 0, 'claim ID should start from 0');
    cheat_caller_address(contract_address, beneficiary, CheatSpan::Indefinite);

    let success = dispatcher.collect_claim(0, malicious, 2563);

    assert(success, 'Claim unsuccessful');
}

#[test]
#[should_panic(expected: 'Invalid claim code')]
fn test_collect_claim_with_wrong_code() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
    let malicious: ContractAddress = contract_address_const::<'malicious'>();

    // Test input values
    let name: felt252 = 'John';
    let email: felt252 = 'John@yahoo.com';
    let personal_message = 'i love you my son';
    let claim_code = 2563;

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

    // Call create_claim
    let claim_id = dispatcher
        .create_claim(name, email, beneficiary, personal_message, 1000, claim_code);

    // Validate that the claim ID is correctly incremented
    assert(claim_id == 0, 'claim ID should start from 0');
    cheat_caller_address(contract_address, beneficiary, CheatSpan::Indefinite);

    let success = dispatcher.collect_claim(0, beneficiary, 63);

    assert(success, 'Claim unsuccessful');
}

#[test]
#[should_panic(expected: 'You have already made a claim')]
fn test_collect_claim_twice() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
    let malicious: ContractAddress = contract_address_const::<'malicious'>();

    // Test input values
    let name: felt252 = 'John';
    let email: felt252 = 'John@yahoo.com';
    let personal_message = 'i love you my son';
    let claim_code = 2563;

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

    // Call create_claim
    let claim_id = dispatcher
        .create_claim(name, email, beneficiary, personal_message, 1000, claim_code);

    // Validate that the claim ID is correctly incremented
    assert(claim_id == 0, 'claim ID should start from 0');
    cheat_caller_address(contract_address, beneficiary, CheatSpan::Indefinite);

    let success = dispatcher.collect_claim(0, beneficiary, 2563);

    assert(success, 'Claim unsuccessful');

    let success2 = dispatcher.collect_claim(0, beneficiary, 2563);
}


#[test]
fn test_collect_create_profile() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let caller: ContractAddress = contract_address_const::<'benefactor'>();

    // Test input values
    let username: felt252 = 'John1234';
    let email: felt252 = 'John@yahoo.com';
    let fullname = 'John Doe';
    let image = 'image';

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, caller, CheatSpan::Indefinite);

    // Call create_claim
    let claim_id = dispatcher.create_profile(username, email, fullname, image);

    // Validate that the claim ID is correctly incremented

    cheat_caller_address(contract_address, caller, CheatSpan::Indefinite);

    let new_profile = dispatcher.get_profile(caller);

    assert(new_profile.username == username, 'Wrong Username');
    assert(new_profile.email == email, ' Wrong email');
    assert(new_profile.full_name == fullname, ' Wrong fullname');
    assert(new_profile.profile_image == image, ' Wrong image');
    assert(new_profile.address == caller, ' Wrong Owner');
}


#[test]
fn test_delete_profile() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let caller: ContractAddress = contract_address_const::<'benefactor'>();

    // Test input values
    let username: felt252 = 'John1234';
    let email: felt252 = 'John@yahoo.com';
    let fullname = 'John Doe';
    let image = 'image';

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, caller, CheatSpan::Indefinite);

    // Call create_claim
    let claim_id = dispatcher.create_profile(username, email, fullname, image);

    // Validate that the claim ID is correctly incremented

    cheat_caller_address(contract_address, caller, CheatSpan::Indefinite);
    let success = dispatcher.delete_user_profile(caller);
    assert(success, 'Deletion Failed');
    let new_profile = dispatcher.get_profile(caller);

    assert(new_profile.username == ' ', 'Wrong Username');
    assert(new_profile.email == ' ', ' Wrong email');
    assert(new_profile.full_name == ' ', ' Wrong fullname');
    assert(new_profile.profile_image == ' ', ' Wrong image');
}

#[test]
#[should_panic(expected: 'No right to delete')]
fn test_non_authorized_delete_profile() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let caller: ContractAddress = contract_address_const::<'benefactor'>();
    let malicious: ContractAddress = contract_address_const::<'malicious'>();

    // Test input values
    let username: felt252 = 'John1234';
    let email: felt252 = 'John@yahoo.com';
    let fullname = 'John Doe';
    let image = 'image';

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, caller, CheatSpan::Indefinite);

    // Call create_claim
    let claim_id = dispatcher.create_profile(username, email, fullname, image);

    // Validate that the claim ID is correctly incremented

    cheat_caller_address(contract_address, malicious, CheatSpan::Indefinite);
    let success = dispatcher.delete_user_profile(caller);
    assert(success, 'Deletion Failed');
    let new_profile = dispatcher.get_profile(caller);

    assert(new_profile.username == ' ', 'Wrong Username');
    assert(new_profile.email == ' ', ' Wrong email');
    assert(new_profile.full_name == ' ', ' Wrong fullname');
    assert(new_profile.profile_image == ' ', ' Wrong image');
}
