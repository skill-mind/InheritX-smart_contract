#[cfg(test)]
mod tests {
    use super::*;
    use starknet::{ContractAddress, contract_address_const};
    use inheritx::interfaces::IInheritX::{IInheritXDispatcher, IInheritXDispatcherTrait};
    use inheritx::InheritX::InheritX;
    use snforge_std::{
        declare, DeclareResultTrait, ContractClassTrait, stop_cheat_caller_address,
        start_cheat_caller_address,
    };

    // Sets up the environment for testing
    fn set_up() -> (IInheritXDispatcher, ContractAddress) {
        // Declare and deploy the account contracts
        let inheritX_class = declare("InheritX").unwrap().contract_class();

        let (contract_address, _) = inheritX_class.deploy(@array![]).unwrap();

        let dispatcher = IInheritXDispatcher { contract_address };

        (dispatcher, contract_address)
    }

    #[test]
    fn test_add_beneficiary_success() {
        let (inheritx_dispatcher, contract_address) = set_up();
        // Setup test parameters
        let plan_id = 1_u256;
        let owner = contract_address_const::<'owner'>();
        let beneficiary = contract_address_const::<'beneficiary'>();
        let name = 'Alice';
        let email = 'alice@inheritx.com';

        // Initialize plan
        start_cheat_caller_address(contract_address, owner);
        inheritx_dispatcher.set_plan_asset_owner(plan_id, owner);
        inheritx_dispatcher.set_max_guardians(5_u8);

        // Execute test
        let result = inheritx_dispatcher.add_beneficiary(plan_id, name, email, beneficiary);

        // Verify results
        assert(result == 0, 'Wrong index returned');

        let count = inheritx_dispatcher.get_plan_beneficiaries_count(plan_id);
        stop_cheat_caller_address(contract_address);

        assert(count == 1, 'Beneficiary count mismatch');

        assert(
            inheritx_dispatcher.get_plan_beneficiaries(plan_id, 0_u32) == beneficiary,
            'Beneficiary not stored',
        );

        assert(inheritx_dispatcher.is_beneficiary(plan_id, beneficiary), 'Flag
        not set');
    }

    #[test]
    #[should_panic]
    fn test_add_to_nonexistent_plan() {
        let (inheritx_dispatcher, _) = set_up();

        let addr1 = contract_address_const::<'addr1'>();

        inheritx_dispatcher.add_beneficiary(999_u256, 'Bob', 'bob@test.com', addr1);
    }

    #[test]
    #[should_panic]
    fn test_unauthorized_caller() {
        let (inheritx_dispatcher, contract_address) = set_up();

        let addr1 = contract_address_const::<'addr1'>();
        let addr2 = contract_address_const::<'addr2'>();

        let plan_id = 1_u256;
        inheritx_dispatcher.set_plan_asset_owner(plan_id, addr1);

        start_cheat_caller_address(contract_address, addr2);
        inheritx_dispatcher.add_beneficiary(plan_id, 'Charlie', 'charlie@test.com', addr1);
        stop_cheat_caller_address(contract_address);
    }

    #[test]
    #[should_panic]
    fn test_add_to_executed_plan() {
        let (inheritx_dispatcher, contract_address) = set_up();

        let owner = contract_address_const::<'owner'>();
        let addr1 = contract_address_const::<'addr1'>();

        let plan_id = 1_u256;
        inheritx_dispatcher.set_plan_asset_owner(plan_id, owner);
        inheritx_dispatcher.set_plan_transfer_date(plan_id, 123456_u64); // Non-zero date
        start_cheat_caller_address(contract_address, owner);
        inheritx_dispatcher.add_beneficiary(plan_id, 'Dave', 'dave@test.com', addr1);
        stop_cheat_caller_address(contract_address);
    }

    #[test]
    #[should_panic]
    fn test_duplicate_beneficiary() {
        let (inheritx_dispatcher, contract_address) = set_up();

        let plan_id = 1_u256;
        let owner = contract_address_const::<'owner'>();
        let beneficiary = contract_address_const::<'beneficiary'>();

        inheritx_dispatcher.set_plan_asset_owner(plan_id, owner);
        start_cheat_caller_address(contract_address, owner);

        // First addition (success)
        inheritx_dispatcher.add_beneficiary(plan_id, 'Frank', 'frank@test.com', beneficiary);

        // Second addition (should fail)
        inheritx_dispatcher.add_beneficiary(plan_id, 'Frank2', 'frank2@test.com', beneficiary);
        stop_cheat_caller_address(contract_address);
    }

    #[test]
    #[should_panic]
    fn test_max_beneficiaries_reached() {
        let (inheritx_dispatcher, contract_address) = set_up();

        let plan_id = 1_u256;
        let owner = contract_address_const::<'owner'>();
        let addr1 = contract_address_const::<'addr1'>();
        let addr2 = contract_address_const::<'addr2'>();

        inheritx_dispatcher.set_plan_asset_owner(plan_id, owner);
        inheritx_dispatcher.set_max_guardians(1_u8); // Set max to 1
        start_cheat_caller_address(contract_address, owner);

        // Add first beneficiary
        inheritx_dispatcher.add_beneficiary(plan_id, 'Grace', 'grace@test.com', addr1);

        // Attempt second beneficiary
        inheritx_dispatcher.add_beneficiary(plan_id, 'Heidi', 'heidi@test.com', addr2);
    }

    #[test]
    #[should_panic]
    fn test_empty_name() {
        let (inheritx_dispatcher, contract_address) = set_up();

        let plan_id = 1_u256;
        let owner = contract_address_const::<'owner'>();
        let addr1 = contract_address_const::<'addr1'>();

        inheritx_dispatcher.set_plan_asset_owner(plan_id, owner);
        start_cheat_caller_address(contract_address, owner);

        inheritx_dispatcher.add_beneficiary(plan_id, 0, // Empty name
        'invalid@test.com', addr1);
    }

    #[test]
    #[should_panic]
    fn test_empty_email() {
        let (inheritx_dispatcher, contract_address) = set_up();

        let plan_id = 1_u256;

        let owner = contract_address_const::<'owner'>();
        let addr1 = contract_address_const::<'addr1'>();

        inheritx_dispatcher.set_plan_asset_owner(plan_id, owner);
        start_cheat_caller_address(contract_address, owner);

        inheritx_dispatcher.add_beneficiary(plan_id, 'Valid Name', 0, // Empty email
        addr1);
    }
}
