#[cfg(test)]
mod tests {
    use inheritx::InheritX::InheritX;
    use inheritx::interfaces::IInheritX::{
        AssetAllocation, IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait,
    };
    use inheritx::types::{
        ActivityType, MediaMessage, NotificationSettings, NotificationStruct, PlanConditions,
        PlanOverview, PlanSection, PlanStatus, SecuritySettings, SimpleBeneficiary, TokenInfo,
        UserProfile, UserRole, VerificationStatus,
    };
    use snforge_std::{
        CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_block_timestamp,
        cheat_caller_address, declare, start_cheat_block_timestamp, start_cheat_caller_address,
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
    // Helper function to setup contract with a test plan
    fn setup_with_plan() -> (IInheritXDispatcher, u256, ContractAddress) {
        let (IInheritXDispatcher, contract_address) = setup();
        let dispatcher = IInheritXDispatcher { contract_address };
        let owner: ContractAddress = contract_address_const::<'owner'>();
        let beneficiary1: ContractAddress = contract_address_const::<'beneficiary1'>();
        let beneficiary2: ContractAddress = contract_address_const::<'beneficiary2'>();

        // Create test plan through contract calls
        let plan_id = dispatcher
            .create_inheritance_plan(
                'Test Plan',
                array![
                    AssetAllocation { token: owner, amount: 1000, percentage: 50 },
                    AssetAllocation { token: owner, amount: 2000, percentage: 50 },
                ],
                'Test Description',
                array![beneficiary1, beneficiary2],
            );

        // To test media messages, we would need to add a function to the contract interface
        // that allows adding media messages with recipients. Since that doesn't exist in your
        // current interface, we'll focus on testing the beneficiaries section which we can
        // properly set up through create_inheritance_plan

        (dispatcher, plan_id, contract_address)
    }

    #[test]
    fn test_get_basic_information_section() {
        let (inheritx, plan_id, _) = setup_with_plan();
        // storage_write(contract_address, "InheritX::Storage::plans_tokens_count", array[plan_id]!,
        // 2);

        // let token_info: TokenInfo = array![
        // token_address: ContractAddress,
        // symbol,
        // chain,
        // 450_u256,
        // 1000_u256,
        // ];

        // let map_var_name = "InheritxPlan::Storage::plan_tokens";

        // Write to storage for specific plan_id and token_index
        // storage_write(
        //     inheritx_address,
        //     map_var_name,
        //     array![plan_id.low, plan_id.high, token_index.into()], // Key parts
        //     token_info
        // );

        let result: PlanOverview = inheritx
            .get_plan_section(plan_id, PlanSection::BasicInformation);

        // Verify basic fields
        assert(result.name == 'Test Plan', 'Incorrect plan name');
        assert(result.description == 'Test Description', 'Incorrect description');

        // Verify tokens were loaded
        // assert(result.tokens_transferred.len() == 2, 'Should have 2 tokens');

        // Verify other sections empty
        assert(result.beneficiaries.len() == 0, 'Beneficiaries should be empty');
    }

    #[test]
    fn test_get_beneficiaries_section() {
        let (inheritx, plan_id, _) = setup_with_plan();

        let result = inheritx.get_plan_section(plan_id, PlanSection::Beneficiaries);

        // Verify beneficiaries
        assert(result.beneficiaries.len() == 2, 'Should have 2 beneficiaries');
    }

    #[test]
    #[should_panic(expected: ('Plan does not exist',))]
    fn test_get_nonexistent_plan_section() {
        let (inheritx, plan_id, _) = setup_with_plan();
        inheritx.get_plan_section(999_u256, PlanSection::BasicInformation);
    }

    #[test]
    fn test_empty_sections() {
        let (inheritx, plan_id, _) = setup_with_plan();
        let owner: ContractAddress = contract_address_const::<'owner'>();

        // Create minimal plan
        let plan_id = inheritx
            .create_inheritance_plan(
                'Empty Plan',
                array![AssetAllocation { token: owner, amount: 1000, percentage: 100 }],
                'Empty Description',
                array![owner],
            );

        // Test all sections
        let basic = inheritx.get_plan_section(plan_id, PlanSection::BasicInformation);
        assert(basic.tokens_transferred.len() == 0, 'Should not have tokens');

        let beneficiaries = inheritx.get_plan_section(plan_id, PlanSection::Beneficiaries);
        assert!(beneficiaries.beneficiaries.len() == 1, "Should have only 1 beneficiary");
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

    #[test]
    fn test_update_security_settings() {
        let (IInheritXDispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        start_cheat_caller_address(contract_address, user);
        IInheritXDispatcher
            .create_profile('username', 'email@example.com', 'Full Name', 'image_url');

        // Check initial security settings
        let profile = IInheritXDispatcher.get_profile(user);
        assert(
            profile.security_settings == SecuritySettings::Two_factor_enabled,
            'initial settings incorrect',
        );

        // Update security settings to Two_factor_disabled
        IInheritXDispatcher.update_security_settings(SecuritySettings::Two_factor_disabled);

        // Check updated settings
        let updated_profile = IInheritXDispatcher.get_profile(user);
        assert(
            updated_profile.security_settings == SecuritySettings::Two_factor_disabled,
            'settings not updated',
        );
    }

    #[test]
    #[should_panic(expected: ('Profile does not exist',))]
    fn test_update_security_settings_no_profile() {
        let (IInheritXDispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        // Try to update settings without creating profile
        start_cheat_caller_address(contract_address, user);

        IInheritXDispatcher.update_security_settings(SecuritySettings::Two_factor_disabled);
    }
    #[test]
    fn test_create_plan_without_profile() {
        let (IInheritXDispatcher, contract_address) = setup();
        let user = 'user'.try_into().unwrap();
        let token_address = 'token_contract'.try_into().unwrap();
        let beneficiary = 'beneficiary'.try_into().unwrap();

        // Valid inputs
        let assets = array![
            AssetAllocation { token: token_address, amount: 1000, percentage: 100 },
        ];
        let beneficiaries = array![beneficiary];

        // Set caller
        start_cheat_caller_address(contract_address, user);
        // Create plan without a profile
        let plan_id = IInheritXDispatcher
            .create_inheritance_plan('user_plan', assets, 'user plan description', beneficiaries);

        // Verify the plan was created
        let plan = IInheritXDispatcher.get_inheritance_plan(plan_id);
        assert(plan.is_active, 'Plan should be active');
        assert(plan.owner == user, 'Plan owner should be user');
        assert(plan.total_value == 1000, 'Total value mismatch');
    }


    #[test]
    #[should_panic(expected: ('Not your claim',))]
    fn test_claim_without_profile() {
        let (IInheritXDispatcher, contract_address) = setup();
        let user = 'user'.try_into().unwrap();

        start_cheat_caller_address(contract_address, user);
        // Attempt to claim without profile
        IInheritXDispatcher.collect_claim(1, user, 1234);
    }

    // New Wallet Management Tests

    #[test]
    fn test_add_first_wallet() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let wallet_addr = contract_address_const::<'wallet1'>();
        let wallet_type = 'personal';

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        let success = dispatcher.add_wallet(wallet_addr, wallet_type);
        assert(success, 'add_wallet failed');

        let primary_wallet = dispatcher.get_primary_wallet(user);
        assert(primary_wallet == wallet_addr, 'primary wallet mismatch');

        let wallets = dispatcher.get_user_wallets(user);
        assert(wallets.len() == 1, 'wallet count mismatch');
        let wallet = wallets.at(0);
        assert(*wallet.address == wallet_addr, 'address mismatch');
        assert(*wallet.is_primary, 'should be primary');
        assert(*wallet.wallet_type == wallet_type, 'type mismatch');
        assert(*wallet.added_at > 0, 'added_at not set');
    }

    #[test]
    fn test_add_multiple_wallets() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let wallet1 = contract_address_const::<'wallet1'>();
        let wallet2 = contract_address_const::<'wallet2'>();
        let wallet3 = contract_address_const::<'wallet3'>();
        let wallet_type = 'personal';

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        dispatcher.add_wallet(wallet1, wallet_type);
        dispatcher.add_wallet(wallet2, wallet_type);
        dispatcher.add_wallet(wallet3, wallet_type);

        let wallets = dispatcher.get_user_wallets(user);
        assert(wallets.len() == 3, 'wallet count mismatch');

        let primary_wallet = dispatcher.get_primary_wallet(user);
        assert(primary_wallet == wallet1, 'primary wallet mismatch');
    }

    #[test]
    fn test_set_primary_wallet() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let wallet1 = contract_address_const::<'wallet1'>();
        let wallet2 = contract_address_const::<'wallet2'>();
        let wallet_type = 'personal';

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        dispatcher.add_wallet(wallet1, wallet_type);
        dispatcher.add_wallet(wallet2, wallet_type);

        let success = dispatcher.set_primary_wallet(wallet2);
        assert(success, 'set_primary failed');

        let primary_wallet = dispatcher.get_primary_wallet(user);
        assert(primary_wallet == wallet2, 'primary wallet mismatch');

        let wallets = dispatcher.get_user_wallets(user);
        assert(*wallets.at(0).is_primary == false, 'wallet1 should not be primary');
        assert(*wallets.at(1).is_primary, 'wallet2 should be primary');
    }

    #[test]
    #[should_panic(
        expected: (
            0x46a6158a16a947e5916b2a2ca68501a45e93d7110e81aa2d6438b1c57c879a3,
            0x0,
            'Wallet already exists',
            0x15,
        ),
    )]
    fn test_add_duplicate_wallet() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let wallet_addr = contract_address_const::<'wallet1'>();
        let wallet_type = 'personal';

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        dispatcher.add_wallet(wallet_addr, wallet_type);
        dispatcher.add_wallet(wallet_addr, wallet_type); // Should panic
    }

    #[test]
    #[should_panic(
        expected: (
            0x46a6158a16a947e5916b2a2ca68501a45e93d7110e81aa2d6438b1c57c879a3,
            0x0,
            'Wallet not found',
            0x10,
        ),
    )]
    fn test_set_primary_non_existent_wallet() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let non_existent_wallet = contract_address_const::<'non_existent'>();

        start_cheat_caller_address(contract_address, user);
        dispatcher.set_primary_wallet(non_existent_wallet); // Should panic
    }

    #[test]
    fn test_wallet_types() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let wallet1 = contract_address_const::<'wallet1'>();
        let wallet2 = contract_address_const::<'wallet2'>();
        let type_personal = 'personal';
        let type_inheritance = 'inheritance';

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        dispatcher.add_wallet(wallet1, type_personal);
        dispatcher.add_wallet(wallet2, type_inheritance);

        let wallets = dispatcher.get_user_wallets(user);
        assert(wallets.len() == 2, 'wallet count mismatch');
        assert(*wallets.at(0).wallet_type == type_personal, 'type1 mismatch');
        assert(*wallets.at(1).wallet_type == type_inheritance, 'type2 mismatch');
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
