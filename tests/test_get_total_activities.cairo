#[cfg(test)]
mod tests {
    use super::{InheritX, IInheritX, ActivityType, ContractState};
    use starknet::{ContractAddress, get_caller_address, testing};
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::contract_address_const;
    use starknet::testing::{set_caller_address, set_contract_address};

    // Helper function to setup the contract state
    fn setup() -> ContractState {
        let mut state = InheritX::contract_state_for_testing();
        set_caller_address(contract_address_const::<1>()); // Set admin address
        InheritX::constructor(ref state);
        state
    }

    #[test]
    #[available_gas(2000000)]
    fn test_get_total_activities_initial() {
        // Setup fresh contract state
        let state = setup();
        
        // Initially, total activities should be 0
        let total = InheritX::IInheritXImpl::get_total_activities(@state);
        assert(total == 0, 'Initial total should be 0');
    }

    #[test]
    #[available_gas(2000000)]
    fn test_get_total_activities_after_single_activity() {
        // Setup fresh contract state
        let mut state = setup();
        let user = contract_address_const::<2>();
        
        // Record one activity
        InheritX::IInheritXImpl::record_user_activity(
            ref state,
            user,
            ActivityType::Login,
            'User logged in',
            '192.168.1.1',
            'Test Device'
        );
        
        // Check total activities
        let total = InheritX::IInheritXImpl::get_total_activities(@state);
        assert(total == 1, 'Total should be 1 after one activity');
    }

    #[test]
    #[available_gas(2000000)]
    fn test_get_total_activities_multiple_users() {
        // Setup fresh contract state
        let mut state = setup();
        let user1 = contract_address_const::<2>();
        let user2 = contract_address_const::<3>();
        
        // Record activities for different users
        InheritX::IInheritXImpl::record_user_activity(
            ref state,
            user1,
            ActivityType::Login,
            'User1 logged in',
            '192.168.1.1',
            'Test Device 1'
        );
        
        InheritX::IInheritXImpl::record_user_activity(
            ref state,
            user2,
            ActivityType::ProfileUpdate,
            'User2 updated profile',
            '192.168.1.2',
            'Test Device 2'
        );
        
        // Check total activities
        let total = InheritX::IInheritXImpl::get_total_activities(@state);
        assert(total == 2, 'Total should be 2 after two activities');
    }

    #[test]
    #[available_gas(2000000)]
    fn test_get_total_activities_multiple_activities_same_user() {
        // Setup fresh contract state
        let mut state = setup();
        let user = contract_address_const::<2>();
        
        // Record multiple activities for same user
        InheritX::IInheritXImpl::record_user_activity(
            ref state,
            user,
            ActivityType::Login,
            'First login',
            '192.168.1.1',
            'Test Device'
        );
        
        InheritX::IInheritXImpl::record_user_activity(
            ref state,
            user,
            ActivityType::ProfileUpdate,
            'Profile updated',
            '192.168.1.1',
            'Test Device'
        );
        
        InheritX::IInheritXImpl::record_user_activity(
            ref state,
            user,
            ActivityType::Transfer,
            'Funds transferred',
            '192.168.1.1',
            'Test Device'
        );
        
        // Check total activities
        let total = InheritX::IInheritXImpl::get_total_activities(@state);
        assert(total == 3, 'Total should be 3 after three activities');
    }
}