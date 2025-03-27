#[cfg(test)]
mod tests {
    use inheritx::InheritX::InheritX;
    use inheritx::interfaces::IInheritX::{IInheritXDispatcher, IInheritXDispatcherTrait};
    use inheritx::types::ActivityType;
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use starknet::{ContractAddress, contract_address_const};
    use super::*;

    // Sets up the environment for testing
    fn setup() -> (IInheritXDispatcher, ContractAddress) {
        // Declare and deploy the account contracts
        let inheritX_class = declare("InheritX").unwrap().contract_class();

        let (contract_address, _) = inheritX_class.deploy(@array![]).unwrap();

        let dispatcher = IInheritXDispatcher { contract_address };

        (dispatcher, contract_address)
    }


    #[test]
    fn test_initial_data() {
        let (IInheritXDispatcher, contract_address) = setup();

        let dispatcher = IInheritXDispatcher { contract_address };
        // Ensure dispatcher methods exist
        let deployed = dispatcher.test_deployment();

        assert(deployed == true, 'deployment failed');
    }

    #[test]
    fn test_is_verified() {
        let (IInheritXDispatcher, contract_address) = setup();
        let caller = contract_address_const::<'address'>();
        let dispatcher = IInheritXDispatcher { contract_address };
        // Ensure dispatcher methods exist
        let deployed = dispatcher.test_deployment();
        start_cheat_caller_address(contract_address, caller);
        let is_verified = dispatcher.is_verified(caller);
        assert(is_verified == false, 'should be unverified');
    }

    #[test]
    #[should_panic(expected: 'Code expired')]
    fn test_is_expired() {
        let (IInheritXDispatcher, contract_address) = setup();
        let caller = contract_address_const::<'address'>();
        let dispatcher = IInheritXDispatcher { contract_address };
        // Ensure dispatcher methods exist
        let deployed = dispatcher.test_deployment();
        start_cheat_caller_address(contract_address, caller);
        let is_expired = dispatcher.check_expiry(caller);
        assert(is_expired == true, 'should not be expired');
    }

    #[test]
    fn test_get_verification_status() {
        let (IInheritXDispatcher, contract_address) = setup();
        let caller = contract_address_const::<'address'>();
        let dispatcher = IInheritXDispatcher { contract_address };
        // Ensure dispatcher methods exist
        start_cheat_caller_address(contract_address, caller);
        let verification_status = dispatcher.get_verification_status(20, caller);
        assert(verification_status == false, 'should be unverified');
    }

    #[test]
    #[should_panic(expected: 'Code expired')]
    fn test_complete_verification() {
        let (IInheritXDispatcher, contract_address) = setup();
        let caller = contract_address_const::<'address'>();
        let dispatcher = IInheritXDispatcher { contract_address };
        // Ensure dispatcher methods exist
        start_cheat_caller_address(contract_address, caller);
        let verification_status_before = dispatcher.get_verification_status(20, caller);
        assert(verification_status_before == false, 'should be unverified');
        let complete_verification = dispatcher.complete_verififcation(caller, 20);
        let verification_status_after = dispatcher.get_verification_status(20, caller);
        assert(verification_status_after == true, 'should not be unverified');
    }


    #[test]
    fn test_get_activity_history_empty() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        // Check initial activity history length
        let history_length = dispatcher.get_activity_history_length(user);
        assert(history_length == 0, 'Initial history should be empty');

        // Try to retrieve history
        let history = dispatcher.get_activity_history(user, 0, 10);
        assert(history.len() == 0, 'History should be empty');
    }

    #[test]
    fn test_get_activity_history_pagination() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        // Record multiple activities
        let _activity1_id = dispatcher
            .record_user_activity(
                user, ActivityType::Login, 'First login', '192.168.1.1', 'Desktop Chrome',
            );

        let _activity2_id = dispatcher
            .record_user_activity(
                user,
                ActivityType::ProfileUpdate,
                'Profile details updated',
                '192.168.1.2',
                'Mobile Safari',
            );

        let _activity3_id = dispatcher
            .record_user_activity(
                user,
                ActivityType::WalletConnection,
                'Wallet connected',
                '192.168.1.3',
                'Mobile Android',
            );

        // Check total history length
        let history_length = dispatcher.get_activity_history_length(user);
        assert(history_length == 3, 'Incorrect history length');

        // Test first page (2 records)
        let first_page = dispatcher.get_activity_history(user, 0, 2);
        assert(first_page.len() == 2, 'should have 2 records');

        // Test second page (1 record)
        let second_page = dispatcher.get_activity_history(user, 2, 2);
        assert(second_page.len() == 1, 'should have 1 record');
    }

    #[test]
    #[should_panic(expected: ('Page size must be positive',))]
    fn test_get_activity_history_invalid_page_size() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        // Should panic with zero page size
        dispatcher.get_activity_history(user, 0, 0);
    }
}
