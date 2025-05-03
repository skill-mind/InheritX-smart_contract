use inheritx::interfaces::ICounterLogic::{ICounterLogicDispatcher, ICounterLogicDispatcherTrait};
use inheritx::interfaces::ICounterLogicV2::{
    ICounterLogicV2Dispatcher, ICounterLogicV2DispatcherTrait,
};
use inheritx::interfaces::IProxy::{IProxyDispatcher, IProxyDispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_block_timestamp, declare,
    get_class_hash, start_cheat_block_timestamp, start_cheat_caller_address,
    stop_cheat_block_timestamp, stop_cheat_caller_address,
};
use starknet::syscalls::deploy_syscall;
use starknet::{ClassHash, ContractAddress, SyscallResultTrait, contract_address_const};

#[cfg(test)]
mod tests {
    use core::result::ResultTrait;
    use inheritx::InheritX::InheritX;
    use inheritx::interfaces::ICounterLogic::{
        ICounterLogicDispatcher, ICounterLogicDispatcherTrait,
    };
    use inheritx::interfaces::ICounterLogicV2::{
        ICounterLogicV2Dispatcher, ICounterLogicV2DispatcherTrait,
    };
    use inheritx::interfaces::IInheritX::{
        AssetAllocation, IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait,
    };
    use inheritx::interfaces::IProxy::{IProxyDispatcher, IProxyDispatcherTrait};
    use inheritx::types::{
        ActivityType, MediaMessage, NotificationSettings, NotificationStruct, PlanConditions,
        PlanOverview, PlanSection, PlanStatus, SecuritySettings, SimpleBeneficiary, TokenInfo,
        UserProfile, UserRole, VerificationStatus,
    };
    use snforge_std::{
        CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_block_timestamp,
        cheat_caller_address, declare, get_class_hash, start_cheat_block_timestamp,
        start_cheat_caller_address, stop_cheat_block_timestamp, stop_cheat_caller_address,
    };
    use starknet::class_hash::ClassHash;
    use starknet::syscalls::deploy_syscall;
    use starknet::testing::{set_caller_address, set_contract_address};
    use starknet::{ContractAddress, SyscallResultTrait, contract_address_const};
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

        // Call create_inheritance_plan
        let plan_id = dispatcher
            .create_inheritance_plan(plan_name, assets, description, pick_beneficiaries);

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

        (dispatcher, plan_id, contract_address)
    }

    #[test]
    #[should_panic(expected: 'Plan does not exist')]
    fn test_get_basic_information_section() {
        let (inheritx, plan_id, _) = setup_with_plan();

        let result: PlanOverview = inheritx
            .get_plan_section(plan_id, PlanSection::BasicInformation);

        // Verify basic fields
        assert(result.name == 'Test Plan', 'Incorrect plan name');
        assert(result.description == 'Test Description', 'Incorrect description');

        // Verify other sections empty
        assert(result.beneficiaries.len() == 0, 'Beneficiaries should be empty');
    }

    #[test]
    #[should_panic(expected: ('Plan does not exist',))]
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
        let create_minimal_plan = inheritx
            .create_inheritance_plan(
                'Empty Plan',
                array![AssetAllocation { token: owner, amount: 1000, percentage: 100 }],
                'Empty Description',
                array![owner],
            );
        let plan_id: u256 = 1;

        // Test all sections
        let basic = inheritx.get_plan_section(plan_id, PlanSection::BasicInformation);
        assert(basic.tokens_transferred.len() == 0, 'Should not have tokens');
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
    #[should_panic(expected: 'Not your claim')]
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

    #[test]
    fn test_plan_validation() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let user1 = contract_address_const::<'user1'>();
        let user2 = contract_address_const::<'user2'>();
        let users = contract_address_const::<'users'>();

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        let asset_allocations = array![
            AssetAllocation { token: contract_address, amount: 10256, percentage: 50 },
        ];

        // Create initial valid plan
        let plan_id: u256 = 1;
        dispatcher
            .create_inheritance_plan(
                'Test Plan',
                array![AssetAllocation { token: contract_address, amount: 10256, percentage: 50 }],
                'Test Description',
                array![user, user1, user2, users],
            );

        let beneficiary_plan = dispatcher.check_beneficiary_plan(1);
        assert(beneficiary_plan, 'invalid tokens');

        // Simulate claiming the plan
        let mut plan = dispatcher.get_inheritance_plan(plan_id);
        assert(plan.is_claimed == false, 'plan should be claimed');
        plan.is_claimed = true;

        assert(!dispatcher.is_plan_valid(plan_id), 'be invalid after claiming');
        // Reset and test other modifications
        plan.is_claimed = false;
    }

    #[test]
    fn test_plan_validation_after1() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let user1 = contract_address_const::<'user1'>();
        let user2 = contract_address_const::<'user2'>();
        let users = contract_address_const::<'users'>();

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        let asset_allocations = array![
            AssetAllocation { token: contract_address, amount: 10256, percentage: 50 },
        ];

        // Create initial valid plan
        let plan_id: u256 = 1;
        dispatcher
            .create_inheritance_plan(
                'Test Plan',
                array![AssetAllocation { token: contract_address, amount: 10256, percentage: 50 }],
                'Test Description',
                array![user, user1, user2, users],
            );

        assert(dispatcher.is_valid_plan_status(plan_id), 'should be invalid');
    }

    #[test]
    fn test_plan_validation_remove_asset() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let user1 = contract_address_const::<'user1'>();
        let user2 = contract_address_const::<'user2'>();
        let users = contract_address_const::<'users'>();

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        let asset_allocations = array![
            AssetAllocation { token: contract_address, amount: 10256, percentage: 50 },
        ];

        // Create initial valid plan
        let plan_id: u256 = 1;
        dispatcher
            .create_inheritance_plan(
                'Test Plan',
                array![AssetAllocation { token: contract_address, amount: 10256, percentage: 50 }],
                'Test Description',
                array![user, user1, user2, users],
            );

        // Remove all assets
        dispatcher.write_to_asset_count(plan_id, 0);
        assert(!dispatcher.is_plan_valid(plan_id), 'Plan should be invalid');
    }

    #[test]
    fn test_plan_validation_remove_beneficiary() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let user1 = contract_address_const::<'user1'>();
        let user2 = contract_address_const::<'user2'>();
        let users = contract_address_const::<'users'>();

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        let asset_allocations = array![
            AssetAllocation { token: contract_address, amount: 10256, percentage: 50 },
        ];

        // Create initial valid plan
        let plan_id: u256 = 1;
        dispatcher
            .create_inheritance_plan(
                'Test Plan',
                array![AssetAllocation { token: contract_address, amount: 10256, percentage: 50 }],
                'Test Description',
                array![user, user1, user2, users],
            );

        // Restore assets but remove beneficiaries
        dispatcher.write_to_asset_count(plan_id, 1);
        dispatcher.write_to_beneficiary_count(plan_id, 0);
        assert(!dispatcher.is_plan_valid(plan_id), 'Plan should be invalid');
    }

    #[test]
    fn test_create_claim() {
        let (dispatcher, contract_address) = setup();
        let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();

        // Test input values
        let name: felt252 = 'John';
        let email: felt252 = 'John@yahoo.com';
        let personal_message = 'i love you my son';
        let claim_code = 2563;

        // Ensure the caller is the admin
        cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

        // Call create_claim
        let claim_id = dispatcher
            .create_claim(name, email, beneficiary, personal_message, 1000, claim_code);

        // Validate that the claim ID is correctly incremented
        assert(claim_id == 0, 'claim ID should start from 0');

        // Retrieve the claim to verify it was stored correctly
        let claim = dispatcher.retrieve_claim(claim_id);
        assert(claim.id == claim_id, 'claim ID mismatch');
        assert(claim.name == name, 'claim title mismatch');
        assert(claim.personal_message == personal_message, 'claim description mismatch');
        assert(claim.code == claim_code, 'claim price mismatch');
        assert(claim.wallet_address == beneficiary, 'cbenificiary address mismatch');
        assert(claim.email == email, 'claim email mismatch');
        assert(claim.benefactor == benefactor, 'benefactor address mismatch');
    }

    #[test]
    fn test_collect_claim() {
        let (dispatcher, contract_address) = setup();
        let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();

        // Test input values
        let name: felt252 = 'John';
        let email: felt252 = 'John@yahoo.com';
        let personal_message = 'i love you my son';
        let claim_code = 2563;

        // Ensure the caller is the admin
        cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

        // Call create_claim
        let claim_id = dispatcher
            .create_claim(name, email, beneficiary, personal_message, 1000, claim_code);

        // Validate that the claim ID is correctly incremented
        assert(claim_id == 0, 'claim ID should start from 0');
        cheat_caller_address(contract_address, beneficiary, CheatSpan::Indefinite);

        let success = dispatcher.collect_claim(0, beneficiary, 2563);

        assert(success, 'Claim unsuccessful');
    }

    #[test]
    #[should_panic(expected: 'Not your claim')]
    fn test_collect_claim_with_wrong_address() {
        let (dispatcher, contract_address) = setup();
        let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
        let malicious: ContractAddress = contract_address_const::<'malicious'>();

        // Test input values
        let name: felt252 = 'John';
        let email: felt252 = 'John@yahoo.com';
        let personal_message = 'i love you my son';
        let claim_code = 2563;

        // Ensure the caller is the admin
        cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

        // Call create_claim
        let claim_id = dispatcher
            .create_claim(name, email, beneficiary, personal_message, 1000, claim_code);

        // Validate that the claim ID is correctly incremented
        assert(claim_id == 0, 'claim ID should start from 0');
        cheat_caller_address(contract_address, beneficiary, CheatSpan::Indefinite);

        let success = dispatcher.collect_claim(0, malicious, 2563);

        assert(success, 'Claim unsuccessful');
    }

    #[test]
    #[should_panic(expected: 'Invalid claim code')]
    fn test_collect_claim_with_wrong_code() {
        let (dispatcher, contract_address) = setup();
        let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
        let malicious: ContractAddress = contract_address_const::<'malicious'>();

        // Test input values
        let name: felt252 = 'John';
        let email: felt252 = 'John@yahoo.com';
        let personal_message = 'i love you my son';
        let claim_code = 2563;

        // Ensure the caller is the admin
        cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

        // Call create_claim
        let claim_id = dispatcher
            .create_claim(name, email, beneficiary, personal_message, 1000, claim_code);

        // Validate that the claim ID is correctly incremented
        assert(claim_id == 0, 'claim ID should start from 0');
        cheat_caller_address(contract_address, beneficiary, CheatSpan::Indefinite);

        let success = dispatcher.collect_claim(0, beneficiary, 63);

        assert(success, 'Claim unsuccessful');
    }

    #[test]
    #[should_panic(expected: 'You have already made a claim')]
    fn test_collect_claim_twice() {
        let (dispatcher, contract_address) = setup();
        let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
        let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
        let malicious: ContractAddress = contract_address_const::<'malicious'>();

        // Test input values
        let name: felt252 = 'John';
        let email: felt252 = 'John@yahoo.com';
        let personal_message = 'i love you my son';
        let claim_code = 2563;

        // Ensure the caller is the admin
        cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

        // Call create_claim
        let claim_id = dispatcher
            .create_claim(name, email, beneficiary, personal_message, 1000, claim_code);

        // Validate that the claim ID is correctly incremented
        assert(claim_id == 0, 'claim ID should start from 0');
        cheat_caller_address(contract_address, beneficiary, CheatSpan::Indefinite);

        let success = dispatcher.collect_claim(0, beneficiary, 2563);

        assert(success, 'Claim unsuccessful');

        let success2 = dispatcher.collect_claim(0, beneficiary, 2563);
    }

    #[test]
    fn test_collect_create_profile() {
        let (dispatcher, contract_address) = setup();
        let caller: ContractAddress = contract_address_const::<'benefactor'>();

        // Test input values
        let username: felt252 = 'John1234';
        let email: felt252 = 'John@yahoo.com';
        let fullname = 'John Doe';
        let image = 'image';

        // Ensure the caller is the admin
        cheat_caller_address(contract_address, caller, CheatSpan::Indefinite);

        // Call create_claim
        let claim_id = dispatcher.create_profile(username, email, fullname, image);

        // Validate that the claim ID is correctly incremented

        cheat_caller_address(contract_address, caller, CheatSpan::Indefinite);

        let new_profile = dispatcher.get_profile(caller);

        assert(new_profile.username == username, 'Wrong Username');
        assert(new_profile.email == email, ' Wrong email');
        assert(new_profile.full_name == fullname, ' Wrong fullname');
        assert(new_profile.profile_image == image, ' Wrong image');
        assert(new_profile.address == caller, ' Wrong Owner');
    }

    #[test]
    fn test_delete_profile() {
        let (dispatcher, contract_address) = setup();
        let caller: ContractAddress = contract_address_const::<'benefactor'>();

        // Test input values
        let username: felt252 = 'John1234';
        let email: felt252 = 'John@yahoo.com';
        let fullname = 'John Doe';
        let image = 'image';

        // Ensure the caller is the admin
        cheat_caller_address(contract_address, caller, CheatSpan::Indefinite);

        // Call create_claim
        let claim_id = dispatcher.create_profile(username, email, fullname, image);

        // Validate that the claim ID is correctly incremented

        cheat_caller_address(contract_address, caller, CheatSpan::Indefinite);
        let success = dispatcher.delete_user_profile(caller);
        assert(success, 'Deletion Failed');
        let new_profile = dispatcher.get_profile(caller);

        assert(new_profile.username == ' ', 'Wrong Username');
        assert(new_profile.email == ' ', ' Wrong email');
        assert(new_profile.full_name == ' ', ' Wrong fullname');
        assert(new_profile.profile_image == ' ', ' Wrong image');
    }

    #[test]
    #[should_panic(expected: 'No right to delete')]
    fn test_non_authorized_delete_profile() {
        let (dispatcher, contract_address) = setup();
        let caller: ContractAddress = contract_address_const::<'benefactor'>();
        let malicious: ContractAddress = contract_address_const::<'malicious'>();

        // Test input values
        let username: felt252 = 'John1234';
        let email: felt252 = 'John@yahoo.com';
        let fullname = 'John Doe';
        let image = 'image';

        // Ensure the caller is the admin
        cheat_caller_address(contract_address, caller, CheatSpan::Indefinite);

        // Call create_claim
        let claim_id = dispatcher.create_profile(username, email, fullname, image);

        // Validate that the claim ID is correctly incremented

        cheat_caller_address(contract_address, malicious, CheatSpan::Indefinite);
        let success = dispatcher.delete_user_profile(caller);
        assert(success, 'Deletion Failed');
        let new_profile = dispatcher.get_profile(caller);

        assert(new_profile.username == ' ', 'Wrong Username');
        assert(new_profile.email == ' ', ' Wrong email');
        assert(new_profile.full_name == ' ', ' Wrong fullname');
        assert(new_profile.profile_image == ' ', ' Wrong image');
    }

    #[test]
    fn test_record_user_activity() {
        let (dispatcher, contract_address) = setup();
        // setup test data
        let user = contract_address_const::<'caller'>();
        let activity_type = ActivityType::Login;
        let details: felt252 = 'login by user';
        let ip_address: felt252 = '0.0.0.0';
        let device_info: felt252 = 'tester_device';

        // call record activity
        let activity_id: u256 = dispatcher
            .record_user_activity(user, activity_type, details, ip_address, device_info);

        // assertion calls
        let activity = dispatcher.get_user_activity(user, activity_id);
        assert(activity.device_info == device_info, 'invalid device info');
        assert(activity.ip_address == ip_address, 'invalid ip address');
        assert(activity.details == details, 'invalid details');
    }

    // Recovery Tests
    #[test]
    fn test_generate_recovery_code() {
        // Setup
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user1'>();

        // Set specific block timestamp for deterministic testing
        let test_timestamp = 1648000000_u64;
        start_cheat_block_timestamp(contract_address, test_timestamp);

        // Call function
        let recovery_code = dispatcher.generate_recovery_code(user);

        // Since the function uses block timestamp and number which can vary,
        // we can verify that the code is not zero, which would indicate failure
        assert(recovery_code != 0, 'Recovery code can not be zero');

        // Generate code again and ensure it's different (timestamp should change)
        start_cheat_block_timestamp(contract_address, test_timestamp + 100);
        let new_recovery_code = dispatcher.generate_recovery_code(user);
        assert(recovery_code != new_recovery_code, 'Codes should be different');

        stop_cheat_block_timestamp(contract_address);
    }

    #[test]
    fn test_initiate_recovery() {
        // Setup
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user1'>();

        // Create user profile
        start_cheat_caller_address(contract_address, user);
        dispatcher.create_profile('username', 'email@example.com', 'Full Name', 'image_url');

        // Set block timestamp
        let test_timestamp = 1648000000_u64;
        start_cheat_block_timestamp(contract_address, test_timestamp);

        // Call initiate_recovery
        let recovery_code = dispatcher.initiate_recovery(user, 'email');

        // Verify code is not zero
        assert(recovery_code != 0, 'Recovery code can not be zero');

        // Verify code is valid
        let is_valid = dispatcher.verify_recovery_code(user, recovery_code);
        assert(is_valid, 'Code should be valid');

        stop_cheat_block_timestamp(contract_address);
    }

    #[test]
    #[should_panic(expected: ('User profile does not exist',))]
    fn test_initiate_recovery_nonexistent_user() {
        let (dispatcher, contract_address) = setup();
        let nonexistent_user = contract_address_const::<'nonexistent'>();

        // This should fail with "User profile does not exist"
        dispatcher.initiate_recovery(nonexistent_user, 'email');
    }

    #[test]
    fn test_verify_recovery_code() {
        // Setup
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user1'>();

        // Create user profile
        start_cheat_caller_address(contract_address, user);
        dispatcher.create_profile('username', 'email@example.com', 'Full Name', 'image_url');

        // Set block timestamp
        let test_timestamp = 1648000000_u64;
        start_cheat_block_timestamp(contract_address, test_timestamp);

        // Initiate recovery
        let recovery_code = dispatcher.initiate_recovery(user, 'email');

        // Verify valid code
        let is_valid = dispatcher.verify_recovery_code(user, recovery_code);
        assert(is_valid, 'Code should be valid');

        // Test invalid code
        let invalid_code = recovery_code + 1;
        let is_invalid = dispatcher.verify_recovery_code(user, invalid_code);
        assert(!is_invalid, 'Invalid code should not verify');

        stop_cheat_block_timestamp(contract_address);
    }

    #[test]
    fn test_verify_recovery_code_expired() {
        // Setup
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user1'>();

        // Create user profile
        start_cheat_caller_address(contract_address, user);
        dispatcher.create_profile('username', 'email@example.com', 'Full Name', 'image_url');

        // Set block timestamp
        let test_timestamp = 1648000000_u64;
        start_cheat_block_timestamp(contract_address, test_timestamp);

        // Initiate recovery
        let recovery_code = dispatcher.initiate_recovery(user, 'email');

        // Set timestamp after expiry (3600 seconds + 1)
        start_cheat_block_timestamp(contract_address, test_timestamp + 3601);

        // Verify expired code
        let is_valid = dispatcher.verify_recovery_code(user, recovery_code);
        assert(!is_valid, 'Expired code can not be valid');

        stop_cheat_block_timestamp(contract_address);
    }

    #[test]
    fn test_verify_recovery_code_cleanup() {
        // Setup
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user1'>();

        // Create user profile
        start_cheat_caller_address(contract_address, user);
        dispatcher.create_profile('username', 'email@example.com', 'Full Name', 'image_url');

        // Initiate recovery
        let test_timestamp = 1648000000_u64;
        start_cheat_block_timestamp(contract_address, test_timestamp);
        let recovery_code = dispatcher.initiate_recovery(user, 'email');

        // Verify code (this should clear the code and expiry)
        let is_valid = dispatcher.verify_recovery_code(user, recovery_code);
        assert(is_valid, 'Code should be valid initially');

        // Try to verify again - should fail because code was cleared
        let is_still_valid = dispatcher.verify_recovery_code(user, recovery_code);
        assert(!is_still_valid, 'Code expires after use');

        stop_cheat_block_timestamp(contract_address);
    }


    #[test]
    fn test_plan_modifications() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let beneficiary1 = contract_address_const::<'beneficiary1'>();
        let beneficiary2 = contract_address_const::<'beneficiary2'>();

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        // Create initial plan
        let plan_id = dispatcher
            .create_inheritance_plan(
                'Test Plan',
                array![AssetAllocation { token: contract_address, amount: 1000, percentage: 100 }],
                'Test Description',
                array![beneficiary1],
            );

        // Add new beneficiary
        dispatcher.add_beneficiary(plan_id, 'Beneficiary 2', 'ben2@example.com', beneficiary2);

        // Verify beneficiaries
        let beneficiary_count = dispatcher.get_plan_beneficiaries_count(plan_id);
        assert(beneficiary_count == 2, 'Should have 2 beneficiaries');

        // Verify beneficiary is added
        assert(dispatcher.is_beneficiary(plan_id, beneficiary2), 'Beneficiary 2 should be added');
    }


    #[test]
    fn test_plan_asset_distribution() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let beneficiary1 = contract_address_const::<'beneficiary1'>();
        let beneficiary2 = contract_address_const::<'beneficiary2'>();

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        // Create plan with multiple assets
        let plan_id = dispatcher
            .create_inheritance_plan(
                'Test Plan',
                array![
                    AssetAllocation { token: contract_address, amount: 1000, percentage: 60 },
                    AssetAllocation { token: contract_address, amount: 1000, percentage: 40 },
                ],
                'Test Description',
                array![beneficiary1, beneficiary2],
            );

        // Get plan overview
        let plan = dispatcher.get_inheritance_plan(plan_id);
        assert(plan.total_value == 2000, 'Total value should be 2000');
    }

    #[test]
    fn test_plan_beneficiary_management() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let beneficiary1 = contract_address_const::<'beneficiary1'>();
        let beneficiary2 = contract_address_const::<'beneficiary2'>();

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        // Create initial plan
        let plan_id = dispatcher
            .create_inheritance_plan(
                'Test Plan',
                array![AssetAllocation { token: contract_address, amount: 1000, percentage: 100 }],
                'Test Description',
                array![beneficiary1],
            );

        // Add second beneficiary
        dispatcher.add_beneficiary(plan_id, 'Beneficiary 2', 'ben2@example.com', beneficiary2);

        // Verify beneficiaries
        let beneficiary_count = dispatcher.get_plan_beneficiaries_count(plan_id);
        assert(beneficiary_count == 2, 'Should have 2 beneficiaries');

        // Verify both beneficiaries are added
        assert(dispatcher.is_beneficiary(plan_id, beneficiary1), 'Beneficiary 1 should exist');
        assert(dispatcher.is_beneficiary(plan_id, beneficiary2), 'Beneficiary 2 should exist');
    }
}

// Counter Logic and Proxy Test Helpers
fn deploy_counter_logic_v1() -> ClassHash {
    let owner = contract_address_const::<'owner'>();
    // Declare the V1 contract
    let declare_result = declare("CounterLogicV1").unwrap().contract_class();
    let (address, _) = declare_result.deploy(@array![owner.into()]).unwrap();

    get_class_hash(address)
}

fn deploy_counter_logic_v2() -> ClassHash {
    let owner = contract_address_const::<'owner'>();
    // Declare the V1 contract
    let declare_result = declare("CounterLogicV2").unwrap().contract_class();
    let (address, _) = declare_result.deploy(@array![owner.into()]).unwrap();

    get_class_hash(address)
}

fn deploy_counter_instance(class_hash: ClassHash) -> (ContractAddress, ContractAddress) {
    let owner = contract_address_const::<0x123>();

    // Deploy logic with constructor args
    let mut calldata = array![];
    calldata.append(owner.into());

    let (contract_address, _) = deploy_syscall(class_hash, 0, calldata.span(), false)
        .unwrap_syscall();

    (contract_address, owner)
}

fn deploy_proxy(implementation_hash: ClassHash) -> ContractAddress {
    let owner = contract_address_const::<0x123>();

    // Declare the proxy contract
    let declare_result = declare("CounterProxy").unwrap().contract_class();

    // Deploy with constructor args
    let mut calldata = ArrayTrait::<felt252>::new();
    calldata.append(owner.into());
    calldata.append(implementation_hash.into());

    let (proxy_address, _) = declare_result.deploy(@calldata).unwrap();

    proxy_address
}

// Counter Logic and Proxy Tests
#[test]
fn test_implementation_upgrade() {
    // Deploy initial logic contract (v1)
    let logic_hash_v1 = deploy_counter_logic_v1();
    let logic_address_v1 = deploy_counter_instance(logic_hash_v1);

    // Deploy proxy with logic implementation
    let proxy_address = deploy_proxy(logic_hash_v1);

    // Set caller to owner
    let owner = contract_address_const::<0x123>();
    start_cheat_caller_address(proxy_address, owner);

    // Check proxy implementation
    let proxy_dispatcher = IProxyDispatcher { contract_address: proxy_address };
    let initial_impl = proxy_dispatcher.get_implementation();
    assert(initial_impl == logic_hash_v1, 'Initial impl should be v1');

    // Deploy v2 implementation
    let logic_hash_v2 = deploy_counter_logic_v2();
    let logic_address_v2 = deploy_counter_instance(logic_hash_v2);

    // Upgrade proxy to new logic
    proxy_dispatcher.upgrade(logic_hash_v2);

    // Check implementation was updated
    let new_impl = proxy_dispatcher.get_implementation();
    assert(new_impl == logic_hash_v2, 'Implementation not updated');
}

#[test]
fn test_functionality() {
    // Deploy v1 implementation
    let logic_hash_v1 = deploy_counter_logic_v1();
    let (logic_address_v1, owner) = deploy_counter_instance(logic_hash_v1);

    start_cheat_caller_address(logic_address_v1, owner);
    // Test v1 functionality
    let v1_dispatcher = ICounterLogicDispatcher { contract_address: logic_address_v1 };

    // Check initial version
    let version = v1_dispatcher.get_version();
    assert(version == 'v1.0', 'Wrong initial version');
}

#[test]
fn test_increment_functionality() {
    // Deploy v1 implementation
    let logic_hash_v1 = deploy_counter_logic_v1();
    let (logic_address_v1, owner) = deploy_counter_instance(logic_hash_v1);

    start_cheat_caller_address(logic_address_v1, owner);
    // Test v1 functionality
    let v1_dispatcher = ICounterLogicDispatcher { contract_address: logic_address_v1 };

    // Increment counter
    v1_dispatcher.increment();
    v1_dispatcher.increment();

    // Check counter value
    let counter = v1_dispatcher.get_counter();
    assert(counter == 2, 'Counter should be 2');
}

#[test]
fn test_deploy_v2_increment_by() {
    // Deploy v2 implementation
    let logic_hash_v2 = deploy_counter_logic_v2();
    let (logic_address_v2, owner) = deploy_counter_instance(logic_hash_v2);

    // Test v2 functionality
    let v2_dispatcher = ICounterLogicV2Dispatcher { contract_address: logic_address_v2 };

    // Check version
    let v2_version = v2_dispatcher.get_version();
    assert(v2_version == 'v2.0', 'Wrong v2 version');

    start_cheat_caller_address(logic_address_v2, owner);
    v2_dispatcher.increment_by(3);
    stop_cheat_caller_address(logic_address_v2);
    let counter_after = v2_dispatcher.get_counter();
    assert(counter_after == 3, 'Counter should be 3');
}

#[test]
fn test_deploy_v2_reset() {
    // Deploy v2 implementation
    let logic_hash_v2 = deploy_counter_logic_v2();
    let (logic_address_v2, owner) = deploy_counter_instance(logic_hash_v2);

    // Test v2 functionality
    let v2_dispatcher = ICounterLogicV2Dispatcher { contract_address: logic_address_v2 };

    // Check version
    let v2_version = v2_dispatcher.get_version();
    assert(v2_version == 'v2.0', 'Wrong v2 version');

    start_cheat_caller_address(logic_address_v2, owner);
    v2_dispatcher.reset();
    stop_cheat_caller_address(logic_address_v2);
    let counter_reset = v2_dispatcher.get_counter();
    assert(counter_reset == 0, 'Counter should be reset to 0');
}

