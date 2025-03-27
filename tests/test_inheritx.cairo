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
    use inheritx::interfaces::IInheritX::{IInheritXDispatcher, IInheritXDispatcherTrait};
  use inheritx::types::ActivityType;

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
