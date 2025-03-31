#[test]
fn test_add_beneficiary_to_plan_valid() {
    // Setup
    let mut contract = ContractState::default();
    let plan_id = 1_u256;
    let new_beneficiaries = ArrayTrait::new();
    new_beneficiaries.append(ContractAddress::from(0x123));
    new_beneficiaries.append(ContractAddress::from(0x456));

    // Initialize state
    contract.plans_id.write(plan_id);
    contract.plan_beneficiaries_count.write(plan_id, 0);

    // Call function
    contract.add_beneficiary_to_plan(plan_id, new_beneficiaries);

    // Assertions
    assert(contract.plan_beneficiaries_count.read(plan_id) == 2, 'Beneficiary count mismatch');
    assert(contract.is_beneficiary.read((plan_id, ContractAddress::from(0x123))), 'Beneficiary 0x123 not added');
    assert(contract.is_beneficiary.read((plan_id, ContractAddress::from(0x456))), 'Beneficiary 0x456 not added');
}

#[test]
fn test_add_beneficiary_to_plan_invalid_plan_id() {
    // Setup
    let mut contract = ContractState::default();
    let plan_id = 2_u256; // Invalid plan ID
    let new_beneficiaries = ArrayTrait::new();
    new_beneficiaries.append(ContractAddress::from(0x123));

    // Initialize state
    contract.plans_id.write(1_u256); // Only plan ID 1 exists

    // Call function and expect failure
    assert_panics(|| {
        contract.add_beneficiary_to_plan(plan_id, new_beneficiaries);
    }, 'Invalid plan id');
}

#[test]
fn test_add_beneficiary_to_plan_empty_beneficiaries() {
    // Setup
    let mut contract = ContractState::default();
    let plan_id = 1_u256;
    let new_beneficiaries = ArrayTrait::new(); // Empty array

    // Initialize state
    contract.plans_id.write(plan_id);

    // Call function and expect failure
    assert_panics(|| {
        contract.add_beneficiary_to_plan(plan_id, new_beneficiaries);
    }, 'Count cannot be zero');
}

#[test]
fn test_add_beneficiary_to_plan_existing_beneficiaries() {
    // Setup
    let mut contract = ContractState::default();
    let plan_id = 1_u256;
    let new_beneficiaries = ArrayTrait::new();
    new_beneficiaries.append(ContractAddress::from(0x789));

    // Initialize state
    contract.plans_id.write(plan_id);
    contract.plan_beneficiaries_count.write(plan_id, 1);
    contract.plan_beneficiaries.write((plan_id, 0), ContractAddress::from(0x123));
    contract.is_beneficiary.write((plan_id, ContractAddress::from(0x123)), true);

    // Call function
    contract.add_beneficiary_to_plan(plan_id, new_beneficiaries);

    // Assertions
    assert(contract.plan_beneficiaries_count.read(plan_id) == 2, 'Beneficiary count mismatch');
    assert(contract.is_beneficiary.read((plan_id, ContractAddress::from(0x789))), 'Beneficiary 0x789 not added');
}

#[test]
fn test_add_beneficiary_to_plan_multiple_calls() {
    // Setup
    let mut contract = ContractState::default();
    let plan_id = 1_u256;
    let new_beneficiaries_1 = ArrayTrait::new();
    new_beneficiaries_1.append(ContractAddress::from(0x123));
    let new_beneficiaries_2 = ArrayTrait::new();
    new_beneficiaries_2.append(ContractAddress::from(0x456));

    // Initialize state
    contract.plans_id.write(plan_id);
    contract.plan_beneficiaries_count.write(plan_id, 0);

    // Call function twice
    contract.add_beneficiary_to_plan(plan_id, new_beneficiaries_1);
    contract.add_beneficiary_to_plan(plan_id, new_beneficiaries_2);

    // Assertions
    assert(contract.plan_beneficiaries_count.read(plan_id) == 2, 'Beneficiary count mismatch');
    assert(contract.is_beneficiary.read((plan_id, ContractAddress::from(0x123))), 'Beneficiary 0x123 not added');
    assert(contract.is_beneficiary.read((plan_id, ContractAddress::from(0x456))), 'Beneficiary 0x456 not added');
}