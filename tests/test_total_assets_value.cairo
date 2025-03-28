#[cfg(test)]
mod tests {
    use super::InheritX;
    use starknet::{ContractAddress, contract_address_const, get_caller_address};
    use starknet::testing::{set_caller_address, set_contract_address};
    use crate::types::SimpleBeneficiary;

    // Helper function to deploy the contract
    fn setup_contract() -> InheritX::ContractState {
        let mut state = InheritX::contract_state_for_testing();
        // Initialize the contract (call constructor)
        InheritX::constructor(ref state);
        state
    }

    // Helper function to create a claim
    fn create_test_claim(
        ref state: InheritX::ContractState,
        amount: u256,
        beneficiary: ContractAddress,
        claim_code: u256
    ) -> u256 {
        state.create_claim(
            name: 'Test',
            email: 'test@example.com',
            beneficiary: beneficiary,
            personal_message: 'Test message',
            amount: amount,
            claim_code: claim_code
        )
    }

    #[test]
    fn test_initial_total_assets_value() {
        let state = setup_contract();
        let total_value = state.get_total_assets_value();
        assert(total_value == 0, 'Initial value should be 0');
    }

    #[test]
    fn test_total_assets_value_single_claim() {
        let mut state = setup_contract();
        let beneficiary = contract_address_const::<1>();
        let amount = 1000_u256;
        
        // Set caller address for the claim
        set_caller_address(beneficiary);
        set_contract_address(beneficiary);
        
        create_test_claim(ref state, amount, beneficiary, 1234_u256);
        
        let total_value = state.get_total_assets_value();
        assert(total_value == amount, 'Total value should match single claim');
    }

    #[test]
    fn test_total_assets_value_multiple_claims() {
        let mut state = setup_contract();
        let beneficiary1 = contract_address_const::<1>();
        let beneficiary2 = contract_address_const::<2>();
        
        set_caller_address(beneficiary1);
        set_contract_address(beneficiary1);
        
        create_test_claim(ref state, 1000_u256, beneficiary1, 1234_u256);
        create_test_claim(ref state, 2000_u256, beneficiary2, 5678_u256);
        
        let total_value = state.get_total_assets_value();
        assert(total_value == 3000_u256, 'Total value should sum all claims');
    }

    #[test]
    fn test_total_assets_value_after_claim() {
        let mut state = setup_contract();
        let beneficiary = contract_address_const::<1>();
        
        set_caller_address(beneficiary);
        set_contract_address(beneficiary);
        
        let inheritance_id = create_test_claim(ref state, 1000_u256, beneficiary, 1234_u256);
        
        // Before claiming
        let total_before = state.get_total_assets_value();
        assert(total_before == 1000_u256, 'Value before claim incorrect');
        
        // Collect the claim
        let success = state.collect_claim(inheritance_id, beneficiary, 1234_u256);
        assert(success, 'Claim collection failed');
        
        // After claiming
        let total_after = state.get_total_assets_value();
        assert(total_after == 0, 'Value should be 0 after claim');
    }

    #[test]
    fn test_total_assets_value_mixed_claims() {
        let mut state = setup_contract();
        let beneficiary1 = contract_address_const::<1>();
        let beneficiary2 = contract_address_const::<2>();
        
        set_caller_address(beneficiary1);
        set_contract_address(beneficiary1);
        
        let id1 = create_test_claim(ref state, 1000_u256, beneficiary1, 1234_u256);
        let id2 = create_test_claim(ref state, 2000_u256, beneficiary2, 5678_u256);
        
        // Collect first claim
        let success = state.collect_claim(id1, beneficiary1, 1234_u256);
        assert(success, 'Claim collection failed');
        
        let total_value = state.get_total_assets_value();
        assert(total_value == 2000_u256, 'Value should reflect unclaimed amount');
    }
}