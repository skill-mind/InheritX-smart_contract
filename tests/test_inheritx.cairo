#[cfg(test)]
mod tests {
    use inheritx::InheritX::InheritX;
    use inheritx::interfaces::IInheritX::{
        AssetAllocation, IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait,
    };
    use inheritx::types::ActivityType;
    use snforge_std::{
        CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
        cheat_caller_address, declare, spy_events, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use starknet::class_hash::ClassHash;
    use starknet::testing::{set_caller_address, set_contract_address};
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

    #[test]
    fn test_initial_data() {
        let (dispatcher, contract_address) = setup();

        // Ensure dispatcher methods exist
        let deployed = dispatcher.test_deployment();

        assert(deployed, 'deployment failed');
    }

    #[test]
    fn test_create_inheritance_plan() {
        let (dispatcher, contract_address) = setup();
        let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
        let pick_beneficiaries: Array<ContractAddress> = array![beneficiary];
        let assets: Array<AssetAllocation> = array![
            AssetAllocation { token: benefactor, amount: 1000, percentage: 50 },
            AssetAllocation { token: beneficiary, amount: 1000, percentage: 50 },
        ];
        let plan_name: felt252 = 'plan1';
        let description: felt252 = 'plan_desc';

        // Ensure the caller is the admin
        // cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

        // Call create_inheritance_plan
        let plan_id = dispatcher
            .create_inheritance_plan(plan_name, assets, description, pick_beneficiaries);

        // assert(plan_id == 1, 'create_inheritance_plan failed');
        let plan = dispatcher.get_inheritance_plan(plan_id);
        assert(plan.is_active, 'is_active mismatch');
        assert(!plan.is_claimed, 'is_claimed mismatch');
        assert(plan.total_value == 2000, 'total_value mismatch');
    }

    #[test]
    #[should_panic(expected: ('No assets specified',))]
    fn test_create_inheritance_plan_no_assets() {
        let (dispatcher, contract_address) = setup();
        let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
        let pick_beneficiaries: Array<ContractAddress> = array![benefactor];
        let plan_name: felt252 = 'plan1';
        let description: felt252 = 'plan_desc';

        // Ensure the caller is the admin
        // cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

        // Test with no assets
        let assets: Array<AssetAllocation> = array![];
        dispatcher.create_inheritance_plan(plan_name, assets, description, pick_beneficiaries);
    }

    #[test]
    #[should_panic(expected: ('No beneficiaries specified',))]
    fn test_create_inheritance_plan_no_beneficiaries() {
        let (dispatcher, contract_address) = setup();
        let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
        let pick_beneficiaries: Array<ContractAddress> = array![];
        let plan_name: felt252 = 'plan1';
        let description: felt252 = 'plan_desc';

        // Ensure the caller is the admin
        // cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

        let assets: Array<AssetAllocation> = array![
            AssetAllocation { token: benefactor, amount: 1000, percentage: 50 },
            AssetAllocation { token: beneficiary, amount: 1000, percentage: 50 },
        ];
        dispatcher.create_inheritance_plan(plan_name, assets, description, pick_beneficiaries);
    }

    #[test]
    fn test_get_all_notification_preferences() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        // Check initial activity history length
        let notification = dispatcher.get_all_notification_preferences(user);
        // Try to retrieve history

        assert(notification.email_notifications == false, 'should be false');
        assert(notification.push_notifications == false, 'should be false');
        assert(notification.claim_alerts == false, 'should be false');
        assert(notification.plan_updates == false, 'should be false');
        assert(notification.security_alerts == false, 'should be false');
        assert(notification.marketing_updates == false, 'should be false');
    }

    #[test]
    fn test_update_user_notification_preferences() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        // Check initial activity history length
        let notification = dispatcher.update_notification(user, true, true, true, true, true, true);

        // Try to retrieve update

        assert(notification.email_notifications == true, 'should be true');
        assert(notification.push_notifications == true, 'should be true');
        assert(notification.claim_alerts == true, 'should be true');
        assert(notification.plan_updates == true, 'should be true');
        assert(notification.security_alerts == true, 'should be true');
        assert(notification.marketing_updates == true, 'should be true');
    }

    #[test]
    fn test_confirm_update_notification_preferences() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        // Check initial activity history length
        let notification = dispatcher
            .update_notification(user, false, false, false, true, true, true);

        // Try to retrieve update

        assert(notification.email_notifications == false, 'should be true');
        assert(notification.push_notifications == false, 'should be true');
        assert(notification.claim_alerts == false, 'should be true');
        assert(notification.plan_updates == true, 'should be true');
        assert(notification.security_alerts == true, 'should be true');
        assert(notification.marketing_updates == true, 'should be true');
    }

    #[test]
    fn test_confirm_user_notification_preferences() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let Admin = contract_address_const::<'Admin'>();

        // Check initial activity history length
        let notification = dispatcher
            .update_notification(Admin, true, true, false, true, false, true);

        // Try to retrieve update

        assert(notification.email_notifications == true, 'should be true');
        assert(notification.push_notifications == true, 'should be true');
        assert(notification.claim_alerts == false, 'should be true');
        assert(notification.plan_updates == true, 'should be true');
        assert(notification.security_alerts == false, 'should be false');
        assert(notification.marketing_updates == true, 'should be true');
    }

    #[test]
    fn test_event_notification_preferences() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        // Check initial activity history length
        let notification = dispatcher
            .update_notification(user, false, false, false, true, true, true);

        // Try to retrieve update

        assert(notification.email_notifications == false, 'should be true');
        assert(notification.push_notifications == false, 'should be true');
        assert(notification.claim_alerts == false, 'should be true');
        assert(notification.plan_updates == true, 'should be true');
        assert(notification.security_alerts == true, 'should be true');
        assert(notification.marketing_updates == true, 'should be true');
    }
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
