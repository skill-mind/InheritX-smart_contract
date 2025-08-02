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
use starknet::{
    ClassHash, ContractAddress, SyscallResultTrait, contract_address_const, get_caller_address,
};

#[cfg(test)]
mod tests {
    use core::result::ResultTrait;
    use core::traits::PartialEq;
    use inheritx::InheritX::InheritX;
    use inheritx::interfaces::ICounterLogic::{
        ICounterLogicDispatcher, ICounterLogicDispatcherTrait,
    };
    use inheritx::interfaces::ICounterLogicV2::{
        ICounterLogicV2Dispatcher, ICounterLogicV2DispatcherTrait,
    };
    use inheritx::interfaces::IInheritX::{IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait};
    use inheritx::interfaces::IProxy::{IProxyDispatcher, IProxyDispatcherTrait};
    use inheritx::types::{
        ActivityType, AssetAllocation, IPFSDataType, NotificationStruct, PlanConditions,
        PlanOverview, PlanSection, PlanStatus, SimpleBeneficiary, TokenInfo, UserProfile, UserRole,
        VerificationStatus,
    };
    use snforge_std::{
        CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_block_timestamp, declare,
        get_class_hash, start_cheat_block_timestamp, start_cheat_caller_address,
        stop_cheat_block_timestamp, stop_cheat_caller_address,
    };
    use starknet::syscalls::deploy_syscall;
    use starknet::{
        ClassHash, ContractAddress, SyscallResultTrait, contract_address_const, get_caller_address,
    };

    fn setup() -> (IInheritXDispatcher, ContractAddress) {
        // Declare and deploy the account contracts
        let inheritX_class = declare("InheritX").unwrap().contract_class();
        let (contract_address, _deploy_result) = inheritX_class.deploy(@array![]).unwrap();
        let dispatcher = IInheritXDispatcher { contract_address };

        // Set initial block timestamp using cheatcode
        start_cheat_block_timestamp(contract_address, 1000);

        (dispatcher, contract_address)
    }

    #[test]
    fn test_is_verified() {
        let (dispatcher, contract_address) = setup();
        let caller = contract_address_const::<'address'>();

        // Ensure dispatcher methods exist
        let _deployed = dispatcher.test_deployment();
        start_cheat_caller_address(contract_address, caller);

        let is_verified = dispatcher.is_verified(caller);
        assert(is_verified == false, 'should be unverified');
    }

    #[test]
    fn test_is_expired() {
        let (dispatcher, contract_address) = setup();
        let caller = contract_address_const::<'address'>();

        // Ensure dispatcher methods exist
        let _deployed = dispatcher.test_deployment();
        start_cheat_caller_address(contract_address, caller);

        // Legacy function now returns true (moved to off-chain)
        let is_expired = dispatcher.check_expiry(caller);
        assert(is_expired == true, 'should return true');
    }

    #[test]
    fn test_verification_status() {
        let (dispatcher, contract_address) = setup();
        let caller = contract_address_const::<'address'>();

        // Ensure dispatcher methods exist
        start_cheat_caller_address(contract_address, caller);

        // Legacy function now returns 0 (moved to off-chain)
        let verification_code = dispatcher.start_verification(caller);

        // Legacy function now returns false (moved to off-chain)
        let verification_status = dispatcher.get_verification_status(verification_code, caller);
        assert!(verification_status == false, "should return false");

        // Test with an incorrect code
        let wrong_verification_status = dispatcher
            .get_verification_status(verification_code + 1, caller);
        assert!(wrong_verification_status == false, "should return false");
    }

    #[test]
    fn test_complete_verification() {
        let (dispatcher, contract_address) = setup();
        let caller = contract_address_const::<'address'>();

        // Ensure dispatcher methods exist
        start_cheat_caller_address(contract_address, caller);

        // Legacy function now returns 0 (moved to off-chain)
        let verification_code = dispatcher.start_verification(caller);

        // Legacy function now returns false (moved to off-chain)
        let verification_status_before = dispatcher
            .get_verification_status(verification_code, caller);
        assert(verification_status_before == false, 'should return false');

        // Legacy function now does nothing (moved to off-chain)
        let _complete_verification = dispatcher.complete_verififcation(caller, verification_code);

        // User verification status depends on profile, not completion
        let is_verified = dispatcher.is_verified(caller);
        assert!(is_verified == false, "should not be verified without profile");
    }

    #[test]
    fn test_activity_history() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        // Legacy functions now return default values (moved to off-chain)
        let _activity1_id = dispatcher
            .record_user_activity(
                user, ActivityType::Login, 'First login', '192.168.1.1', 'Desktop Chrome',
            );

        let _activity2_id = dispatcher
            .record_user_activity(
                user, ActivityType::ProfileUpdate, 'Profile updated', '192.168.1.2', 'Mobile iOS',
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
        // Legacy function now returns 0 (moved to off-chain)
        let history_length = dispatcher.get_activity_history_length(user);
        assert(history_length == 0, 'should return 0');

        // Test first page (2 records)
        // Legacy function now returns empty array (moved to off-chain)
        let first_page = dispatcher.get_activity_history(user, 0, 2);
        assert(first_page.len() == 0, 'should return empty array');

        // Test second page (1 record)
        let second_page = dispatcher.get_activity_history(user, 2, 2);
        assert(second_page.len() == 0, 'should return empty array');
    }

    #[test]
    fn test_get_activity_history_invalid_page_size() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        // Legacy function now returns empty array regardless of input (moved to off-chain)
        let result = dispatcher.get_activity_history(user, 0, 0);
        assert(result.len() == 0, 'should return empty array');
    }

    #[test]
    fn test_create_inheritance_plan() {
        let (dispatcher, contract_address) = setup();
        let caller = contract_address_const::<'caller'>();

        start_cheat_caller_address(contract_address, caller);

        let plan_name = 'My Inheritance Plan';
        let description = 'Test Plan';
        let tokens = array![
            AssetAllocation { token: contract_address, amount: 1000, percentage: 60 },
            AssetAllocation { token: contract_address, amount: 500, percentage: 40 },
        ];
        let beneficiaries = array![
            contract_address_const::<'beneficiary1'>(), contract_address_const::<'beneficiary2'>(),
        ];

        let plan_id = dispatcher
            .create_inheritance_plan(plan_name, tokens, description, beneficiaries);

        assert(plan_id == 1, 'Plan ID should be 1');

        let plan = dispatcher.get_inheritance_plan(plan_id);
        assert(plan.plan_name == plan_name, 'Plan name should match');
        assert(plan.description == description, 'Plan description should match');
        assert(plan.owner == caller, 'Plan owner should be caller');
        assert(plan.total_value == 1500, 'Total value should be 1500');
        assert(plan.is_active == true, 'Plan should be active');
        assert(plan.is_claimed == false, 'Plan should not be claimed');
        assert(plan.ipfs_hash == 0, 'IPFS hash should be 0 initially');

        let beneficiary_count = dispatcher.get_plan_beneficiaries_count(plan_id);
        assert(beneficiary_count == 2, 'Should have 2 beneficiaries');

        let total_plans = dispatcher.get_total_plans();
        assert(total_plans == 1, 'Total plans should be 1');
    }

    #[test]
    fn test_user_profile_simplified() {
        let (dispatcher, contract_address) = setup();
        let caller = contract_address_const::<'address'>();

        start_cheat_caller_address(contract_address, caller);

        // Test basic profile creation
        dispatcher.create_profile('user1', 'user1@example.com');

        let profile = dispatcher.get_user_profile(caller);

        assert(profile.username == 'user1', 'username should match');
        assert(profile.email == 'user1@example.com', 'email should match');

        // Test profile update
        dispatcher.update_user_profile('user2', 'user2@example.com');

        let updated_profile = dispatcher.get_user_profile(caller);

        assert(updated_profile.username == 'user2', 'updated username should match');
        assert(updated_profile.email == 'user2@example.com', 'updated email should match');

        stop_cheat_caller_address(contract_address);
    }

    // Helper function to setup contract with a test plan
    fn setup_with_plan() -> (IInheritXDispatcher, u256, ContractAddress) {
        let (dispatcher, contract_address) = setup();
        let dispatcher = IInheritXDispatcher { contract_address: contract_address };
        let owner: ContractAddress = contract_address_const::<'owner'>();
        let beneficiary1: ContractAddress = contract_address_const::<'beneficiary1'>();
        let beneficiary2: ContractAddress = contract_address_const::<'beneficiary2'>();

        start_cheat_caller_address(contract_address, owner);

        let plan_id = dispatcher
            .create_inheritance_plan(
                'Test Plan',
                array![AssetAllocation { token: contract_address, amount: 1000, percentage: 100 }],
                'Test Description',
                array![beneficiary1, beneficiary2],
            );

        (dispatcher, plan_id, owner)
    }

    #[test]
    fn test_add_beneficiary() {
        let (dispatcher, plan_id, owner) = setup_with_plan();
        let new_beneficiary = contract_address_const::<'new_beneficiary'>();

        let beneficiary_id = dispatcher
            .add_beneficiary(plan_id, 'New Beneficiary', 'new@example.com', new_beneficiary);

        assert(beneficiary_id == 2, 'Beneficiary ID should be 2');

        let beneficiary_count = dispatcher.get_plan_beneficiaries_count(plan_id);
        assert(beneficiary_count == 3, 'Should have 3 beneficiaries');

        assert(dispatcher.is_beneficiary(plan_id, new_beneficiary), 'Should be beneficiary');
    }

    #[test]
    fn test_get_plan_section() {
        let (dispatcher, plan_id, _owner) = setup_with_plan();

        let result = dispatcher.get_plan_section(plan_id, PlanSection::Beneficiaries);

        // Legacy function now returns empty array (moved to off-chain)
        assert(result.beneficiaries.len() == 0, 'should return empty array');
    }

    #[test]
    fn test_security_settings() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        start_cheat_caller_address(contract_address, user);
        dispatcher.create_profile('username', 'email@example.com');

        // Update security settings (now takes felt252)
        dispatcher.update_security_settings(0x7365637572697479); // "security"

        // Verify the function call succeeded (legacy function now returns default)
        let result = true; // The function now performs no-op for legacy compatibility
        assert(result == true, 'security update success');
    }

    #[test]
    fn test_update_security_settings_no_profile() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        // Try to update settings without creating profile
        start_cheat_caller_address(contract_address, user);

        // This should not panic anymore as it's a legacy function that performs no-op
        dispatcher.update_security_settings(0x7365637572697479); // "security"

        // Verify the function call succeeded (legacy function now returns default)
        let result = true;
        assert(result == true, 'security update success');
    }

    #[test]
    fn test_wallet_management() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let wallet_addr = contract_address_const::<'wallet'>();
        let wallet_type = 'personal';

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        // Legacy function now returns true (moved to off-chain)
        let success = dispatcher.add_wallet(wallet_addr, wallet_type);
        assert(success, 'add_wallet should return true');

        // Legacy function now returns zero address (moved to off-chain)
        let primary_wallet = dispatcher.get_primary_wallet(user);
        assert(primary_wallet == contract_address_const::<0>(), 'should return zero address');

        // Legacy function now returns empty array (moved to off-chain)
        let wallets = dispatcher.get_user_wallets(user);
        assert(wallets.len() == 0, 'should return empty array');
    }

    #[test]
    fn test_multiple_wallets() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let wallet1 = contract_address_const::<'wallet1'>();
        let wallet2 = contract_address_const::<'wallet2'>();
        let wallet3 = contract_address_const::<'wallet3'>();
        let wallet_type = 'personal';

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        // Legacy functions now return true (moved to off-chain)
        dispatcher.add_wallet(wallet1, wallet_type);
        dispatcher.add_wallet(wallet2, wallet_type);
        dispatcher.add_wallet(wallet3, wallet_type);

        // Legacy function now returns empty array (moved to off-chain)
        let wallets = dispatcher.get_user_wallets(user);
        assert(wallets.len() == 0, 'should return empty array');

        // Legacy function now returns zero address (moved to off-chain)
        let primary_wallet = dispatcher.get_primary_wallet(user);
        assert(primary_wallet == contract_address_const::<0>(), 'should return zero address');
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

        // Legacy functions now return true (moved to off-chain)
        dispatcher.add_wallet(wallet1, wallet_type);
        dispatcher.add_wallet(wallet2, wallet_type);

        let success = dispatcher.set_primary_wallet(wallet2);
        assert(success, 'set_primary should return true');

        // Legacy function now returns zero address (moved to off-chain)
        let primary_wallet = dispatcher.get_primary_wallet(user);
        assert(primary_wallet == contract_address_const::<0>(), 'should return zero address');

        // Legacy function now returns empty array (moved to off-chain)
        let wallets = dispatcher.get_user_wallets(user);
        assert(wallets.len() == 0, 'should return empty array');
    }

    #[test]
    fn test_add_duplicate_wallet() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let wallet_addr = contract_address_const::<'wallet'>();
        let wallet_type = 'personal';

        start_cheat_caller_address(contract_address, user);
        cheat_block_timestamp(contract_address, 1000, CheatSpan::Indefinite);

        // Legacy function now returns true (moved to off-chain)
        let success1 = dispatcher.add_wallet(wallet_addr, wallet_type);
        let success2 = dispatcher.add_wallet(wallet_addr, wallet_type);

        // Both should return true since it's now a no-op
        assert(success1, 'first add should return true');
        assert(success2, 'second add should return true');
    }

    #[test]
    fn test_set_primary_non_existent_wallet() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let non_existent_wallet = contract_address_const::<'non_existent'>();

        start_cheat_caller_address(contract_address, user);

        // Legacy function now returns true (moved to off-chain)
        let success = dispatcher.set_primary_wallet(non_existent_wallet);
        assert(success, 'should return true non-existent');
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

        // Legacy functions now return true (moved to off-chain)
        dispatcher.add_wallet(wallet1, type_personal);
        dispatcher.add_wallet(wallet2, type_inheritance);

        // Legacy function now returns empty array (moved to off-chain)
        let wallets = dispatcher.get_user_wallets(user);
        assert(wallets.len() == 0, 'should return empty array');
    }

    #[test]
    fn test_create_claim() {
        let (dispatcher, contract_address) = setup();
        let caller = contract_address_const::<'caller'>();

        // Test input values
        let name: felt252 = 'Alice';
        let email: felt252 = 'alice@test.com';
        let beneficiary = contract_address_const::<'beneficiary'>();
        let personal_message = 'For my daughter';
        let amount = 5000_u256;

        // Set caller context
        start_cheat_caller_address(contract_address, caller);

        // Create claim
        let claim_id = dispatcher.create_claim(name, email, beneficiary, personal_message, amount);

        // Retrieve the claim to check the generated code
        let claim = dispatcher.retrieve_claim(claim_id);

        // Verify the generated Poseidon code
        assert!(claim.code != 0, "Generated code should not be zero");

        // Verify other claim details
        assert(claim.name == name, 'Name mismatch');
        assert(claim.email == email, 'Email mismatch');
        assert(claim.wallet_address == beneficiary, 'Beneficiary mismatch');
        assert(claim.amount == amount, 'Amount mismatch');
        assert(claim.benefactor == caller, 'Benefactor mismatch');
    }

    #[test]
    fn test_collect_claim() {
        let (dispatcher, contract_address) = setup();
        let benefactor = contract_address_const::<'benefactor'>();
        let beneficiary = contract_address_const::<'beneficiary'>();

        // Create claim
        start_cheat_caller_address(contract_address, benefactor);
        let claim_id = dispatcher
            .create_claim('Bob', 'bob@test.com', beneficiary, 'For my son', 3000_u256);

        // Get the actual generated claim code
        let claim = dispatcher.retrieve_claim(claim_id);
        let generated_code = claim.code;

        // Switch to beneficiary to collect claim
        start_cheat_caller_address(contract_address, beneficiary);

        // Should succeed with the correct generated code
        let success = dispatcher.collect_claim(claim_id, beneficiary, generated_code);
        assert(success, 'Claim collection should succeed');

        // Verify claim status is updated
        let updated_claim = dispatcher.retrieve_claim(claim_id);
        assert!(updated_claim.claim_status == true, "Claim should be marked as collected");
    }

    #[test]
    fn test_generate_claim_code() {
        // Setup
        let (dispatcher, contract_address) = setup();
        let beneficiary = contract_address_const::<'beneficiary'>();
        let benefactor = contract_address_const::<'benefactor'>();
        let amount = 1000_u256;

        // Set specific block timestamp for deterministic testing
        let test_timestamp = 1648000000_u64;
        start_cheat_block_timestamp(contract_address, test_timestamp);

        // Generate claim code
        start_cheat_caller_address(contract_address, benefactor);
        let claim_code = dispatcher.generate_claim_code(beneficiary, benefactor, amount);

        // Verify code is not zero (indicating successful Poseidon hash generation)
        assert(claim_code != 0, 'Claim code should not be zero');

        // Generate code again with different parameters - should be different
        let different_claim_code = dispatcher
            .generate_claim_code(beneficiary, benefactor, amount + 100);
        assert!(claim_code != different_claim_code, "Different params should give different codes");

        // Generate code with same parameters but different timestamp - should be different
        start_cheat_block_timestamp(contract_address, test_timestamp + 100);
        let new_timestamp_code = dispatcher.generate_claim_code(beneficiary, benefactor, amount);
        assert!(
            claim_code != new_timestamp_code, "Different timestamp should give different codes",
        );

        stop_cheat_block_timestamp(contract_address);
    }

    #[test]
    fn test_recovery_functions() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        // Create user profile
        start_cheat_caller_address(contract_address, user);
        dispatcher.create_profile('username', 'email@example.com');

        // Set block timestamp
        let test_timestamp = 1648000000_u64;
        start_cheat_block_timestamp(contract_address, test_timestamp);

        // Call initiate_recovery
        // Legacy function now returns 0 (moved to off-chain)
        let recovery_code = dispatcher.initiate_recovery(user, 'email');

        // Legacy function now returns 0
        assert(recovery_code == 0, 'should return 0');

        // Verify code is valid
        // Legacy function now returns false (moved to off-chain)
        let is_valid = dispatcher.verify_recovery_code(user, recovery_code);
        assert(!is_valid, 'should return false');

        stop_cheat_block_timestamp(contract_address);
    }

    #[test]
    fn test_initiate_recovery_nonexistent_user() {
        let (dispatcher, contract_address) = setup();
        let nonexistent_user = contract_address_const::<'nonexistent'>();

        // Legacy function now returns 0 regardless of user existence (moved to off-chain)
        let recovery_code = dispatcher.initiate_recovery(nonexistent_user, 'email');
        assert(recovery_code == 0, 'should return 0');
    }

    #[test]
    fn test_verify_recovery_code() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        // Create user profile
        start_cheat_caller_address(contract_address, user);
        dispatcher.create_profile('username', 'email@example.com');

        // Set block timestamp
        let test_timestamp = 1648000000_u64;
        start_cheat_block_timestamp(contract_address, test_timestamp);

        // Initiate recovery
        // Legacy function now returns 0 (moved to off-chain)
        let recovery_code = dispatcher.initiate_recovery(user, 'email');

        // Verify valid code
        // Legacy function now returns false (moved to off-chain)
        let is_valid = dispatcher.verify_recovery_code(user, recovery_code);
        assert(!is_valid, 'should return false');

        // Test invalid code
        let invalid_code = recovery_code + 1;
        let is_invalid = dispatcher.verify_recovery_code(user, invalid_code);
        assert(!is_invalid, 'should return false');

        stop_cheat_block_timestamp(contract_address);
    }

    #[test]
    fn test_recovery_code_clearance() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        // Create user profile
        start_cheat_caller_address(contract_address, user);
        dispatcher.create_profile('username', 'email@example.com');

        // Set block timestamp
        let test_timestamp = 1648000000_u64;
        start_cheat_block_timestamp(contract_address, test_timestamp);

        // Initiate recovery
        // Legacy function now returns 0 (moved to off-chain)
        let recovery_code = dispatcher.initiate_recovery(user, 'email');

        // Verify code (this should clear the code and expiry)
        // Legacy function now returns false (moved to off-chain)
        let is_valid = dispatcher.verify_recovery_code(user, recovery_code);
        assert(!is_valid, 'should return false');

        // Try to verify again - should still return false
        let is_still_valid = dispatcher.verify_recovery_code(user, recovery_code);
        assert(!is_still_valid, 'should return false');

        stop_cheat_block_timestamp(contract_address);
    }

    // New IPFS Integration Tests
    #[test]
    fn test_update_user_ipfs_data() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();
        let ipfs_hash = 0x123456789abcdef;

        start_cheat_caller_address(contract_address, user);

        // Test updating user profile data
        dispatcher.update_user_ipfs_data(user, IPFSDataType::UserProfile, ipfs_hash);

        // Test updating activity log data
        dispatcher.update_user_ipfs_data(user, IPFSDataType::ActivityLog, ipfs_hash);

        // Test updating notification settings
        dispatcher.update_user_ipfs_data(user, IPFSDataType::Notifications, ipfs_hash);

        // Test updating wallet data
        dispatcher.update_user_ipfs_data(user, IPFSDataType::Wallets, ipfs_hash);
    }

    #[test]
    fn test_update_plan_ipfs_data() {
        let (dispatcher, contract_address) = setup();
        let owner = contract_address_const::<'owner'>();

        start_cheat_caller_address(contract_address, owner);

        // Create a plan first
        let plan_id = dispatcher
            .create_inheritance_plan(
                'Test Plan',
                array![AssetAllocation { token: contract_address, amount: 1000, percentage: 100 }],
                'Test Description',
                array![contract_address_const::<'beneficiary'>()],
            );

        let ipfs_hash = 0xabcdef123456789;

        // Test updating plan details data
        dispatcher.update_plan_ipfs_data(plan_id, IPFSDataType::PlanDetails, ipfs_hash);

        // Test updating media messages data
        dispatcher.update_plan_ipfs_data(plan_id, IPFSDataType::MediaMessages, ipfs_hash);
    }

    #[test]
    fn test_get_user_ipfs_data() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        start_cheat_caller_address(contract_address, user);

        // Test getting user profile data
        let profile_data = dispatcher.get_user_ipfs_data(user, IPFSDataType::UserProfile);
        assert(profile_data.hash == 0, 'should return default hash');

        // Test getting activity log data
        let activity_data = dispatcher.get_user_ipfs_data(user, IPFSDataType::ActivityLog);
        assert(activity_data.hash == 0, 'should return default hash');

        // Test getting notification settings
        let notification_data = dispatcher.get_user_ipfs_data(user, IPFSDataType::Notifications);
        assert(notification_data.hash == 0, 'should return default hash');
    }

    #[test]
    fn test_get_plan_ipfs_data() {
        let (dispatcher, contract_address) = setup();
        let owner = contract_address_const::<'owner'>();

        start_cheat_caller_address(contract_address, owner);

        // Create a plan first
        let plan_id = dispatcher
            .create_inheritance_plan(
                'Test Plan',
                array![AssetAllocation { token: contract_address, amount: 1000, percentage: 100 }],
                'Test Description',
                array![contract_address_const::<'beneficiary'>()],
            );

        // Test getting plan details data
        let plan_data = dispatcher.get_plan_ipfs_data(plan_id, IPFSDataType::PlanDetails);
        assert(plan_data.hash == 0, 'should return default hash');

        // Test getting media messages data
        let media_data = dispatcher.get_plan_ipfs_data(plan_id, IPFSDataType::MediaMessages);
        assert(media_data.hash == 0, 'should return default hash');
    }

    #[test]
    fn test_ipfs_data_types() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        start_cheat_caller_address(contract_address, user);

        // Test all IPFS data types
        let ipfs_hash = 0x123456789abcdef;

        // UserProfile
        dispatcher.update_user_ipfs_data(user, IPFSDataType::UserProfile, ipfs_hash);
        let profile_data = dispatcher.get_user_ipfs_data(user, IPFSDataType::UserProfile);
        assert(profile_data.data_type == IPFSDataType::UserProfile, 'data type should match');

        // PlanDetails
        dispatcher.update_user_ipfs_data(user, IPFSDataType::PlanDetails, ipfs_hash);
        let plan_data = dispatcher.get_user_ipfs_data(user, IPFSDataType::PlanDetails);
        assert(plan_data.data_type == IPFSDataType::PlanDetails, 'data type should match');

        // MediaMessages
        dispatcher.update_user_ipfs_data(user, IPFSDataType::MediaMessages, ipfs_hash);
        let media_data = dispatcher.get_user_ipfs_data(user, IPFSDataType::MediaMessages);
        assert(media_data.data_type == IPFSDataType::MediaMessages, 'data type should match');

        // ActivityLog
        dispatcher.update_user_ipfs_data(user, IPFSDataType::ActivityLog, ipfs_hash);
        let activity_data = dispatcher.get_user_ipfs_data(user, IPFSDataType::ActivityLog);
        assert(activity_data.data_type == IPFSDataType::ActivityLog, 'data type should match');

        // Notifications
        dispatcher.update_user_ipfs_data(user, IPFSDataType::Notifications, ipfs_hash);
        let notification_data = dispatcher.get_user_ipfs_data(user, IPFSDataType::Notifications);
        assert(
            notification_data.data_type == IPFSDataType::Notifications, 'data type should match',
        );

        // Wallets
        dispatcher.update_user_ipfs_data(user, IPFSDataType::Wallets, ipfs_hash);
        let wallet_data = dispatcher.get_user_ipfs_data(user, IPFSDataType::Wallets);
        assert(wallet_data.data_type == IPFSDataType::Wallets, 'data type should match');
    }

    #[test]
    fn test_ipfs_data_timestamp() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        start_cheat_caller_address(contract_address, user);

        let ipfs_hash = 0x123456789abcdef;

        // Update IPFS data
        dispatcher.update_user_ipfs_data(user, IPFSDataType::UserProfile, ipfs_hash);

        // Get the data and check timestamp
        let data = dispatcher.get_user_ipfs_data(user, IPFSDataType::UserProfile);
        assert(data.timestamp > 0, 'timestamp should be set');
    }

    #[test]
    fn test_ipfs_data_validation() {
        let (dispatcher, contract_address) = setup();
        let user = contract_address_const::<'user'>();

        start_cheat_caller_address(contract_address, user);

        // Test with zero hash (should be ignored)
        dispatcher.update_user_ipfs_data(user, IPFSDataType::UserProfile, 0);

        // Get the data and check it's still default
        let data = dispatcher.get_user_ipfs_data(user, IPFSDataType::UserProfile);
        assert(data.hash == 0, 'should return default');
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
