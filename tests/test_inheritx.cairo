#[cfg(test)]
mod tests {
    use inheritx::InheritX::InheritX;
    use inheritx::interfaces::IInheritX::{
        AssetAllocation, IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait,
    };
    use inheritx::types::{
        ActivityType, NotificationSettings, NotificationStruct, SecuritySettings, UserProfile,
        UserRole, VerificationStatus,
    };
    use snforge_std::{
        CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare,
        start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_caller_address,
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

        // Set initial block timestamp using cheatcode
        start_cheat_block_timestamp(contract_address, 1000);
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
    fn test_update_new_user_profile() {
        let (dispatcher, contract_address) = setup();
        let caller = contract_address_const::<'address'>();
        start_cheat_caller_address(contract_address, caller);

        let username = 'newuser';
        let email = 'user@example.com';
        let full_name = 'New User';
        let profile_image = 'image_hash';
        let notification_settings = NotificationSettings::Default;
        let security_settings = SecuritySettings::Two_factor_enabled;

        // Update profile for the first time (creating new profile)
        let result = dispatcher
            .update_user_profile(
                username, email, full_name, profile_image, notification_settings, security_settings,
            );
        assert(result == true, 'Profile update should succeed');

        // Verify the profile was created correctly
        let profile = dispatcher.get_user_profile(caller);
        assert(
            profile.security_settings == SecuritySettings::Two_factor_enabled,
            'should be Two_factor_enabled',
        );

        stop_cheat_caller_address(contract_address);
    }

    #[test]
    fn test_security_settings_enum_values() {
        let (dispatcher, contract_address) = setup();
        let caller = contract_address_const::<'address'>();
        start_cheat_caller_address(contract_address, caller);

        // Test with Nil security settings
        dispatcher
            .update_user_profile(
                'user1',
                'user1@example.com',
                'User One',
                'image1',
                NotificationSettings::Default,
                SecuritySettings::Nil,
            );
        let profile = dispatcher.get_user_profile(caller);
        assert(
            profile.security_settings == SecuritySettings::Nil, 'Security settings should be Nil',
        );

        // Test with recovery_email
        dispatcher
            .update_user_profile(
                'user1',
                'user1@example.com',
                'User One',
                'image1',
                NotificationSettings::Default,
                SecuritySettings::recovery_email,
            );
        let profile = dispatcher.get_user_profile(caller);
        assert(
            profile.security_settings == SecuritySettings::recovery_email,
            'should be recovery_email',
        );

        // Test with backup_guardians
        dispatcher
            .update_user_profile(
                'user1',
                'user1@example.com',
                'User One',
                'image1',
                NotificationSettings::Default,
                SecuritySettings::backup_guardians,
            );
        let profile = dispatcher.get_user_profile(caller);
        assert(
            profile.security_settings == SecuritySettings::backup_guardians,
            'should be backup_guardians',
        );

        stop_cheat_caller_address(contract_address);
    }
}
