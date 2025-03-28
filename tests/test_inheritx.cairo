#[cfg(test)]
mod tests {
    use inheritx::InheritX::InheritX;
    use inheritx::interfaces::IInheritX::{
        AssetAllocation, IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait,
    };
    use inheritx::types::ActivityType;
    use snforge_std::{
        CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_block_timestamp,
        cheat_caller_address, declare, start_cheat_caller_address, stop_cheat_caller_address,
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
