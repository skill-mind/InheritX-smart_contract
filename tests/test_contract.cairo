#[test]
fn test_get_total_assets_value() {
    // Step 1: Deploy the contract
    let mut contract = InheritX::deploy();

    // Step 2: Set up sample inheritance plans
    let beneficiary_1 = ContractAddress::from(0x123); 
    let beneficiary_2 = ContractAddress::from(0x456);

    // Simulate adding inheritance plans
    let inheritance_1 = SimpleBeneficiary {
        id: 0,
        name: 12345,
        email: 67890,
        wallet_address: beneficiary_1,
        personal_message: 99999,
        amount: 100,
        code: 5555,
        claim_status: false, // Not yet claimed
        benefactor: ContractAddress::from(0x999),
    };

    let inheritance_2 = SimpleBeneficiary {
        id: 1,
        name: 54321,
        email: 98760,
        wallet_address: beneficiary_2,
        personal_message: 88888,
        amount: 200,
        code: 6666,
        claim_status: true, // Already claimed
        benefactor: ContractAddress::from(0x999),
    };

    // Step 3: Store these beneficiaries in the contract
    contract.funds.write(0, inheritance_1);
    contract.funds.write(1, inheritance_2);
    contract.plans_id.write(2); // 2 total plans created

    // Step 4: Call the function to check unclaimed assets
    let total_value = contract.get_total_assets_value();

    // Step 5: Assert that only unclaimed funds are counted (100)
    assert_eq!(total_value, 100);
}
