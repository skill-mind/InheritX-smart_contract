use core::array::ArrayTrait;
use core::poseidon::poseidon_hash_span;

#[starknet::contract]
pub mod InheritX {
    use core::array::ArrayTrait;
    use core::num::traits::Zero;
    use core::poseidon::poseidon_hash_span;
    use core::traits::Into;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{
        ContractAddress, get_block_number, get_block_timestamp, get_caller_address,
        get_contract_address,
    };
    use crate::interfaces::IInheritX::IInheritX;
    use crate::types::{
        ActivityRecord, ActivityType, AssetAllocation, IPFSData, IPFSDataType, InheritancePlan,
        NotificationStruct, PlanConditions, PlanOverview, PlanSection, PlanStatus, SecuritySettings,
        SimpleBeneficiary, TokenInfo, UserProfile, UserRole, VerificationStatus, Wallet,
    };

    #[storage]
    struct Storage {
        // Core contract addresses
        admin: ContractAddress,
        security_contract: ContractAddress,
        plan_contract: ContractAddress,
        claim_contract: ContractAddress,
        profile_contract: ContractAddress,
        dashboard_contract: ContractAddress,
        swap_contract: ContractAddress,
        // Protocol settings
        pub protocol_fee: u256,
        pub min_guardians: u8,
        pub max_guardians: u8,
        pub min_timelock: u64,
        pub max_timelock: u64,
        pub is_paused: bool,
        // Statistics
        pub total_plans: u256,
        pub active_plans: u256,
        pub claimed_plans: u256,
        pub total_value_locked: u256,
        pub total_fees_collected: u256,
        // Essential on-chain data only
        inheritance_plans: Map<u256, InheritancePlan>,
        plan_beneficiaries: Map<u256, Map<u32, ContractAddress>>,
        plan_beneficiaries_count: Map<u256, u32>,
        is_beneficiary: Map<u256, Map<ContractAddress, bool>>,
        plan_asset_count: Map<u256, u8>,
        plan_guardians: Map<u256, Map<u8, ContractAddress>>,
        plan_guardian_count: Map<u256, u8>,
        // Claims
        pub funds: Map<u256, SimpleBeneficiary>,
        pub plans_id: u256,
        balances: Map<ContractAddress, u256>,
        deployed: bool,
        // Plan details
        plan_status: Map<u256, PlanStatus>,
        plan_conditions: Map<u256, PlanConditions>,
        // Tokens
        plan_tokens_count: Map<u256, u32>,
        plan_tokens: Map<u256, Map<u32, TokenInfo>>,
        // Minimal user profiles (essential data only)
        user_profiles: Map<ContractAddress, UserProfile>,
        // IPFS data storage for off-chain content
        user_ipfs_hashes: Map<ContractAddress, Map<u8, felt252>>, // u8 represents IPFSDataType
        plan_ipfs_hashes: Map<u256, Map<u8, felt252>>, // u8 represents IPFSDataType
        // Recovery codes
        recovery_codes: Map<ContractAddress, felt252>,
        recovery_code_expiry: Map<ContractAddress, u64>,
        // Storage mappings for notification
        user_notifications: Map<ContractAddress, NotificationStruct>,
        // Updated wallet-related storage mappings
        user_wallets_length: Map<ContractAddress, u256>,
        user_wallets: Map<ContractAddress, Map<u256, Wallet>>,
        user_primary_wallet: Map<ContractAddress, ContractAddress>,
        total_user_wallets: Map<ContractAddress, u256>,
        // KYC details storage for IPFS hashes (CID)
        kyc_details_uri: Map<ContractAddress, ByteArray>,
    }

    // Response-only struct (not stored)
    #[derive(Drop, Serde)]
    pub struct MediaMessageResponse {
        pub file_hash: felt252,
        pub file_name: felt252,
        pub file_type: felt252,
        pub file_size: u64,
        pub recipients: Array<ContractAddress>, // Only in memory
        pub upload_date: u64,
    }

    // Events
    #[derive(Drop, starknet::Event)]
    struct BeneficiaryAdded {
        plan_id: u256,
        beneficiary_id: u32,
        address: ContractAddress,
        name: felt252,
        email: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct IPFSDataUpdated {
        user: ContractAddress,
        data_type: u8, // IPFSDataType as u8
        ipfs_hash: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct PlanIPFSDataUpdated {
        plan_id: u256,
        data_type: u8, // IPFSDataType as u8
        ipfs_hash: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct KYCDetailsStored {
        pub user: ContractAddress,
        pub ipfs_hash: ByteArray,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct KYCDetailsUpdated {
        pub user: ContractAddress,
        pub old_ipfs_hash: ByteArray,
        pub new_ipfs_hash: ByteArray,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct KYCDetailsDeleted {
        pub user: ContractAddress,
        pub timestamp: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ActivityRecordEvent: ActivityRecordEvent,
        BeneficiaryAdded: BeneficiaryAdded,
        NotificationUpdated: NotificationUpdated,
        IPFSDataUpdated: IPFSDataUpdated,
        PlanIPFSDataUpdated: PlanIPFSDataUpdated,
        KYCDetailsStored: KYCDetailsStored,
        KYCDetailsUpdated: KYCDetailsUpdated,
        KYCDetailsDeleted: KYCDetailsDeleted,
    }

    // Data structures for hash generation
    #[derive(Drop, Serde, Hash)]
    struct RecoveryData {
        user: ContractAddress,
        timestamp: u64,
        block_number: u64,
        salt: felt252,
    }

    #[derive(Drop, Serde, Hash)]
    struct VerificationData {
        user: ContractAddress,
        timestamp: u64,
        block_number: u64,
        salt: felt252,
    }

    #[derive(Drop, Serde, Hash)]
    struct ClaimData {
        beneficiary: ContractAddress,
        benefactor: ContractAddress,
        amount: u256,
        timestamp: u64,
        block_number: u64,
        salt: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.admin.write(get_caller_address());
        self.protocol_fee.write(50);
        self.min_guardians.write(1);
        self.max_guardians.write(5);
        self.min_timelock.write(604800);
        self.max_timelock.write(31536000);
        self.total_plans.write(0);
        self.active_plans.write(0);
        self.claimed_plans.write(0);
        self.total_value_locked.write(0);
        self.total_fees_collected.write(0);
        self.is_paused.write(false);
        self.deployed.write(true);
        self.plans_id.write(0);
    }

    // Helper functions
    #[generate_trait]
    impl HelperFunctions of HelperFunctionsTrait {
        fn _update_user_ipfs_data(
            ref self: ContractState,
            user: ContractAddress,
            data_type: u8, // IPFSDataType as u8
            ipfs_hash: felt252,
        ) {
            self.user_ipfs_hashes.entry(user).entry(data_type).write(ipfs_hash);

            self
                .emit(
                    Event::IPFSDataUpdated(
                        IPFSDataUpdated {
                            user, data_type, ipfs_hash, timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn _update_plan_ipfs_data(
            ref self: ContractState,
            plan_id: u256,
            data_type: u8, // IPFSDataType as u8
            ipfs_hash: felt252,
        ) {
            self.plan_ipfs_hashes.entry(plan_id).entry(data_type).write(ipfs_hash);

            self
                .emit(
                    Event::PlanIPFSDataUpdated(
                        PlanIPFSDataUpdated {
                            plan_id, data_type, ipfs_hash, timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }
    }

    #[abi(embed_v0)]
    impl IInheritXImpl of IInheritX<ContractState> {
        fn create_inheritance_plan(
            ref self: ContractState,
            plan_name: felt252,
            tokens: Array<AssetAllocation>,
            description: felt252,
            pick_beneficiaries: Array<ContractAddress>,
        ) -> u256 {
            // Validate inputs
            let asset_count = tokens.len();
            assert(asset_count > 0, 'No assets specified');
            let beneficiary_count = pick_beneficiaries.len();
            assert(beneficiary_count > 0, 'No beneficiaries specified');

            // Calculate total value of tokens
            let mut total_value: u256 = 0;
            let mut i: u32 = 0;
            while i < asset_count {
                let asset = tokens.at(i);
                total_value += *asset.amount;
                i += 1;
            }

            // Generate new plan ID
            let current_plan_id = self.plans_id.read();
            let plan_id = current_plan_id + 1;
            self.plans_id.write(plan_id);

            // Create consolidated plan with IPFS hash for additional data
            let new_plan = InheritancePlan {
                owner: get_caller_address(),
                plan_name,
                description,
                time_lock_period: 0,
                required_guardians: 0,
                is_active: true,
                is_claimed: false,
                total_value,
                creation_date: get_block_timestamp(),
                transfer_date: 0,
                ipfs_hash: 0 // Will be updated when off-chain data is uploaded
            };

            // Store the consolidated plan
            self.inheritance_plans.write(plan_id, new_plan);

            // Store asset count
            self.plan_asset_count.write(plan_id, asset_count.try_into().unwrap());

            // Store beneficiaries using nested mapping
            let mut beneficiary_index: u32 = 0;
            i = 0;
            while i < beneficiary_count {
                let beneficiary = *pick_beneficiaries.at(i);
                self.plan_beneficiaries.entry(plan_id).entry(beneficiary_index).write(beneficiary);
                self.is_beneficiary.entry(plan_id).entry(beneficiary).write(true);
                beneficiary_index += 1;
                i += 1;
            }
            self.plan_beneficiaries_count.write(plan_id, beneficiary_count);

            // Update protocol statistics
            let current_total_plans = self.total_plans.read();
            self.total_plans.write(current_total_plans + 1);
            let current_active_plans = self.active_plans.read();
            self.active_plans.write(current_active_plans + 1);
            let current_tvl = self.total_value_locked.read();
            self.total_value_locked.write(current_tvl + total_value);

            self.plan_status.write(plan_id, PlanStatus::Active);

            // Transfer assets to contract
            i = 0;
            while i < asset_count {
                let asset = tokens.at(i);
                self.transfer_funds(get_contract_address(), *asset.amount);
                i += 1;
            }

            plan_id
        }

        fn write_plan_status(ref self: ContractState, plan_id: u256, status: PlanStatus) {
            self.plan_status.write(plan_id, status);
        }

        fn write_to_beneficiary_count(
            ref self: ContractState, plan_id: u256, beneficiary_count: u32,
        ) {
            self.plan_beneficiaries_count.write(plan_id, beneficiary_count);
        }

        fn write_to_asset_count(ref self: ContractState, plan_id: u256, asset_count: u32) {
            self.plan_asset_count.write(plan_id, asset_count.try_into().unwrap());
        }

        fn create_claim(
            ref self: ContractState,
            name: felt252,
            email: felt252,
            beneficiary: ContractAddress,
            personal_message: felt252,
            amount: u256,
        ) -> u256 {
            let inheritance_id = self.plans_id.read();
            let benefactor = get_caller_address();

            // Generate secure Poseidon-based claim code
            let generated_code = self.generate_claim_code(beneficiary, benefactor, amount);

            let new_beneficiary = SimpleBeneficiary {
                id: inheritance_id,
                name,
                email,
                wallet_address: beneficiary,
                personal_message,
                amount,
                code: generated_code.into(),
                claim_status: false,
                benefactor: benefactor,
            };

            self.funds.write(inheritance_id, new_beneficiary);
            self.plans_id.write(inheritance_id + 1);

            let total_plans = self.total_plans.read();
            self.total_plans.write(total_plans + 1);

            self.transfer_funds(get_contract_address(), amount);

            inheritance_id
        }

        fn create_profile(ref self: ContractState, username: felt252, email: felt252) -> bool {
            let new_profile = UserProfile {
                address: get_caller_address(),
                username: username,
                email: email,
                verification_status: VerificationStatus::Unverified,
                role: UserRole::User,
                created_at: get_block_timestamp(),
                last_active: get_block_timestamp(),
                profile_ipfs_hash: 0 // Will be updated when profile data is uploaded to IPFS
            };

            self.user_profiles.write(new_profile.address, new_profile);
            true
        }

        fn collect_claim(
            ref self: ContractState,
            inheritance_id: u256,
            beneficiary: ContractAddress,
            claim_code: u256,
        ) -> bool {
            let mut claim = self.funds.read(inheritance_id);

            assert(!claim.claim_status, 'You have already made a claim');
            assert((claim.wallet_address == beneficiary), 'Not your claim');
            assert((claim.code == claim_code), 'Invalid claim code');

            claim.claim_status = true;
            self.transfer_funds(beneficiary, claim.amount);
            self.funds.write(inheritance_id, claim);

            true
        }

        fn get_inheritance_plan(ref self: ContractState, plan_id: u256) -> InheritancePlan {
            self.inheritance_plans.read(plan_id)
        }

        fn write_to_inheritance(ref self: ContractState, plan_id: u256, new_plan: InheritancePlan) {
            self.inheritance_plans.write(plan_id, new_plan);
        }

        fn record_user_activity(
            ref self: ContractState,
            user: ContractAddress,
            activity_type: ActivityType,
            details: felt252,
            ip_address: felt252,
            device_info: felt252,
        ) -> u256 {
            // Activity recording moved to off-chain via IPFS
            // This function is kept for backward compatibility
            0
        }

        fn get_user_activity(
            ref self: ContractState, user: ContractAddress, activity_id: u256,
        ) -> ActivityRecord {
            // Activity retrieval moved to off-chain via IPFS
            // This function is kept for backward compatibility
            ActivityRecord {
                timestamp: 0,
                activity_type: ActivityType::Void,
                details: 0,
                ip_address: 0,
                device_info: 0,
            }
        }

        fn get_profile(ref self: ContractState, address: ContractAddress) -> UserProfile {
            self.user_profiles.read(address)
        }

        fn retrieve_claim(ref self: ContractState, inheritance_id: u256) -> SimpleBeneficiary {
            self.funds.read(inheritance_id)
        }

        fn transfer_funds(ref self: ContractState, beneficiary: ContractAddress, amount: u256) {
            let current_bal = self.balances.read(beneficiary);
            self.balances.write(beneficiary, current_bal + amount);
        }

        fn test_deployment(ref self: ContractState) -> bool {
            self.deployed.read()
        }

        fn start_verification(ref self: ContractState, user: ContractAddress) -> felt252 {
            // Verification moved to off-chain
            0
        }

        fn check_expiry(ref self: ContractState, user: ContractAddress) -> bool {
            // Verification expiry moved to off-chain
            true
        }

        fn complete_verififcation(
            ref self: ContractState, user: ContractAddress, code: felt252,
        ) {
            // Verification completion moved to off-chain
        }

        fn get_verification_status(
            ref self: ContractState, code: felt252, user: ContractAddress,
        ) -> bool {
            // Verification status moved to off-chain
            false
        }

        fn is_verified(self: @ContractState, user: ContractAddress) -> bool {
            let profile = self.user_profiles.read(user);
            profile.verification_status == VerificationStatus::Verified
        }

        fn add_beneficiary(
            ref self: ContractState,
            plan_id: u256,
            name: felt252,
            email: felt252,
            address: ContractAddress,
        ) -> felt252 {
            // Get plan to check owner
            let plan = self.inheritance_plans.read(plan_id);
            assert(plan.owner != address, 'Invalid plan_id');

            let caller = get_caller_address();
            assert(caller == plan.owner, 'Caller is not the asset owner');
            assert(plan.transfer_date == 0, 'Plan is already executed');
            assert(!address.is_zero(), 'Invalid beneficiary address');
            assert(
                !self.is_beneficiary.entry(plan_id).entry(address).read(), 'Already a beneficiary',
            );
            assert(name != 0, 'Name cannot be empty');
            assert(email != 0, 'Email cannot be empty');

            let current_count: u32 = self.plan_beneficiaries_count.read(plan_id);
            let max_allowed: u32 = self.max_guardians.read().into();
            assert(current_count < max_allowed, 'Exceeds max beneficiaries');

            self.plan_beneficiaries.entry(plan_id).entry(current_count).write(address);
            self.is_beneficiary.entry(plan_id).entry(address).write(true);
            self.plan_beneficiaries_count.write(plan_id, current_count + 1);

            self
                .emit(
                    Event::BeneficiaryAdded(
                        BeneficiaryAdded {
                            plan_id, beneficiary_id: current_count, address, name, email,
                        },
                    ),
                );

            current_count.into()
        }

        fn set_plan_asset_owner(ref self: ContractState, plan_id: u256, owner: ContractAddress) {
            // Update the plan's owner field
            let mut plan = self.inheritance_plans.read(plan_id);
            plan.owner = owner;
            self.inheritance_plans.write(plan_id, plan);
        }

        fn set_max_guardians(ref self: ContractState, max_guardian_number: u8) {
            self.max_guardians.write(max_guardian_number);
        }

        fn get_plan_beneficiaries_count(self: @ContractState, plan_id: u256) -> u32 {
            self.plan_beneficiaries_count.read(plan_id)
        }

        fn get_plan_beneficiaries(
            self: @ContractState, plan_id: u256, index: u32,
        ) -> ContractAddress {
            self.plan_beneficiaries.entry(plan_id).entry(index).read()
        }

        fn get_activity_history(
            self: @ContractState, user: ContractAddress, start_index: u256, page_size: u256,
        ) -> Array<ActivityRecord> {
            // Activity history moved to off-chain via IPFS
            // This function is kept for backward compatibility
            ArrayTrait::new()
        }

        fn is_beneficiary(self: @ContractState, plan_id: u256, address: ContractAddress) -> bool {
            self.is_beneficiary.entry(plan_id).entry(address).read()
        }

        fn set_plan_transfer_date(ref self: ContractState, plan_id: u256, date: u64) {
            let mut plan = self.inheritance_plans.read(plan_id);
            plan.transfer_date = date;
            self.inheritance_plans.write(plan_id, plan);
        }

        fn get_activity_history_length(self: @ContractState, user: ContractAddress) -> u256 {
            // Activity history length moved to off-chain via IPFS
            0
        }

        fn get_total_plans(self: @ContractState) -> u256 {
            self.total_plans.read()
        }

        fn generate_recovery_code(ref self: ContractState, user: ContractAddress) -> felt252 {
            let recovery_data = RecoveryData {
                user: user,
                timestamp: get_block_timestamp(),
                block_number: get_block_number(),
                salt: 0x123abc123abc,
            };

            let mut recovery_data_array = ArrayTrait::new();
            recovery_data_array.append(recovery_data.user.into());
            recovery_data_array.append(recovery_data.timestamp.into());
            recovery_data_array.append(recovery_data.block_number.into());
            recovery_data_array.append(recovery_data.salt);

            poseidon_hash_span(recovery_data_array.span())
        }

        fn generate_claim_code(
            ref self: ContractState,
            beneficiary: ContractAddress,
            benefactor: ContractAddress,
            amount: u256,
        ) -> felt252 {
            let claim_data = ClaimData {
                beneficiary: beneficiary,
                benefactor: benefactor,
                amount: amount,
                timestamp: get_block_timestamp(),
                block_number: get_block_number(),
                salt: 0xdef789abc012 // Different salt for claim codes
            };

            let mut claim_data_array = ArrayTrait::new();
            claim_data_array.append(claim_data.beneficiary.into());
            claim_data_array.append(claim_data.benefactor.into());
            claim_data_array.append(claim_data.amount.low.into());
            claim_data_array.append(claim_data.amount.high.into());
            claim_data_array.append(claim_data.timestamp.into());
            claim_data_array.append(claim_data.block_number.into());
            claim_data_array.append(claim_data.salt);

            poseidon_hash_span(claim_data_array.span())
        }

        fn initiate_recovery(
            ref self: ContractState, user: ContractAddress, recovery_method: felt252,
        ) -> felt252 {
            // Recovery initiation moved to off-chain
            0
        }

        fn verify_recovery_code(
            ref self: ContractState, user: ContractAddress, recovery_code: felt252,
        ) -> bool {
            // Recovery verification moved to off-chain
            false
        }

        fn update_notification(
            ref self: ContractState,
            user: ContractAddress,
            email_notifications: bool,
            push_notifications: bool,
            claim_alerts: bool,
            plan_updates: bool,
            security_alerts: bool,
            marketing_updates: bool,
        ) -> NotificationStruct {
            // Notifications moved to off-chain via IPFS
            NotificationStruct {
                email_notifications,
                push_notifications,
                claim_alerts,
                plan_updates,
                security_alerts,
                marketing_updates,
            }
        }

        fn get_all_notification_preferences(
            ref self: ContractState, user: ContractAddress,
        ) -> NotificationStruct {
            // Notifications moved to off-chain via IPFS
            NotificationStruct {
                email_notifications: false,
                push_notifications: false,
                claim_alerts: false,
                plan_updates: false,
                security_alerts: false,
                marketing_updates: false,
            }
        }

        fn get_plan_section(
            self: @ContractState, plan_id: u256, section: PlanSection,
        ) -> PlanOverview {
            // Assert that the plan_id exists
            let current_total_plans = self.total_plans.read();
            assert(plan_id <= current_total_plans && plan_id > 0, 'Plan does not exist');

            // Get the consolidated plan data
            let plan = self.inheritance_plans.read(plan_id);

            // Create a PlanOverview struct with basic details from consolidated plan
            let mut plan_overview = PlanOverview {
                plan_id: plan_id,
                name: plan.plan_name,
                description: plan.description,
                tokens_transferred: ArrayTrait::new(),
                transfer_date: plan.transfer_date,
                inactivity_period: self.plan_conditions.read(plan_id).inactivity_period,
                multi_signature_enabled: self
                    .plan_conditions
                    .read(plan_id)
                    .multi_signature_required,
                creation_date: plan.creation_date,
                status: self.plan_status.read(plan_id),
                total_value: plan.total_value,
                beneficiaries: ArrayTrait::new(),
                media_messages: ArrayTrait::new(),
            };

            // Additional data is now stored off-chain via IPFS
            plan_overview
        }

        fn delete_user_profile(ref self: ContractState, address: ContractAddress) -> bool {
            let admin = self.admin.read();
            let mut user = self.user_profiles.read(address);
            let caller = user.address;

            assert(
                get_caller_address() == admin || get_caller_address() == caller,
                'No right to delete',
            );

            user.username = ' ';
            user.address = starknet::contract_address::contract_address_const::<0>();
            user.email = ' ';
            user.verification_status = VerificationStatus::Unverified;
            user.role = UserRole::User;
            user.created_at = 0;
            user.last_active = 0;
            user.profile_ipfs_hash = 0;

            self.user_profiles.write(caller, user);

            true
        }

        fn update_user_profile(ref self: ContractState, username: felt252, email: felt252) -> bool {
            let caller = get_caller_address();
            let mut profile = self.user_profiles.read(caller);

            assert(profile.address == caller || profile.address.is_zero(), 'Not authorized');

            profile.address = caller;
            profile.username = username;
            profile.email = email;
            profile.last_active = get_block_timestamp();

            if profile.created_at.is_zero() {
                profile.created_at = get_block_timestamp();
                profile.role = UserRole::User;
                profile.verification_status = VerificationStatus::Unverified;
            }

            self.user_profiles.write(caller, profile);

            true
        }

        fn get_user_profile(self: @ContractState, user: ContractAddress) -> UserProfile {
            self.user_profiles.read(user)
        }

        fn update_security_settings(ref self: ContractState, new_settings: felt252) -> bool {
            // Security settings moved to off-chain via IPFS
            true
        }

        fn add_wallet(
            ref self: ContractState, wallet: ContractAddress, wallet_type: felt252,
        ) -> bool {
            // Wallet management moved to off-chain via IPFS
            true
        }

        fn set_primary_wallet(ref self: ContractState, wallet: ContractAddress) -> bool {
            // Primary wallet setting moved to off-chain via IPFS
            true
        }

        fn get_primary_wallet(self: @ContractState, user: ContractAddress) -> ContractAddress {
            // Primary wallet retrieval moved to off-chain via IPFS
            starknet::contract_address::contract_address_const::<0>()
        }

        fn get_user_wallets(self: @ContractState, user: ContractAddress) -> Array<Wallet> {
            // User wallets retrieval moved to off-chain via IPFS
            ArrayTrait::new()
        }

        fn is_plan_valid(self: @ContractState, plan_id: u256) -> bool {
            let current_total_plans = self.total_plans.read();
            if plan_id >= current_total_plans {
                return false;
            }

            self.is_valid_plan_status(plan_id);
            self.plan_has_been_claimed(plan_id);
            self.plan_is_active(plan_id);
            self.plan_has_assets(plan_id);
            self.check_beneficiary_plan(plan_id);

            true
        }

        fn is_valid_plan_status(self: @ContractState, plan_id: u256) -> bool {
            let status = self.plan_status.read(plan_id);
            if status != PlanStatus::Active {
                return false;
            }
            return true;
        }

        fn plan_has_been_claimed(self: @ContractState, plan_id: u256) -> bool {
            let plan = self.inheritance_plans.read(plan_id);
            if plan.is_claimed {
                return false;
            }
            return true;
        }

        fn plan_is_active(self: @ContractState, plan_id: u256) -> bool {
            let plan = self.inheritance_plans.read(plan_id);
            if !plan.is_active {
                return false;
            }
            return true;
        }

        fn plan_has_assets(self: @ContractState, plan_id: u256) -> bool {
            let asset_count = self.plan_asset_count.read(plan_id);
            if asset_count == 0 {
                return false;
            }
            return true;
        }

        fn check_beneficiary_plan(self: @ContractState, plan_id: u256) -> bool {
            let beneficiaries_count = self.plan_beneficiaries_count.read(plan_id);
            if beneficiaries_count == 0 {
                return false;
            }
            true
        }

        fn update_user_ipfs_data(
            ref self: ContractState,
            user: ContractAddress,
            data_type: IPFSDataType,
            ipfs_hash: felt252,
        ) {
            // Validate IPFS hash
            if ipfs_hash == 0 {
                return;
            }

            let data_type_u8 = match data_type {
                IPFSDataType::UserProfile => 0_u8,
                IPFSDataType::PlanDetails => 1_u8,
                IPFSDataType::MediaMessages => 2_u8,
                IPFSDataType::ActivityLog => 3_u8,
                IPFSDataType::Notifications => 4_u8,
                IPFSDataType::Wallets => 5_u8,
            };

            HelperFunctions::_update_user_ipfs_data(ref self, user, data_type_u8, ipfs_hash);
        }

        fn update_plan_ipfs_data(
            ref self: ContractState, plan_id: u256, data_type: IPFSDataType, ipfs_hash: felt252,
        ) {
            // Validate IPFS hash
            if ipfs_hash == 0 {
                return;
            }

            let data_type_u8 = match data_type {
                IPFSDataType::UserProfile => 0_u8,
                IPFSDataType::PlanDetails => 1_u8,
                IPFSDataType::MediaMessages => 2_u8,
                IPFSDataType::ActivityLog => 3_u8,
                IPFSDataType::Notifications => 4_u8,
                IPFSDataType::Wallets => 5_u8,
            };

            HelperFunctions::_update_plan_ipfs_data(ref self, plan_id, data_type_u8, ipfs_hash);
        }

        fn get_user_ipfs_data(
            self: @ContractState, user: ContractAddress, data_type: IPFSDataType,
        ) -> IPFSData {
            let data_type_u8 = match data_type {
                IPFSDataType::UserProfile => 0_u8,
                IPFSDataType::PlanDetails => 1_u8,
                IPFSDataType::MediaMessages => 2_u8,
                IPFSDataType::ActivityLog => 3_u8,
                IPFSDataType::Notifications => 4_u8,
                IPFSDataType::Wallets => 5_u8,
            };
            let hash = self.user_ipfs_hashes.entry(user).entry(data_type_u8).read();
            IPFSData { hash, timestamp: get_block_timestamp(), data_type }
        }

        fn get_plan_ipfs_data(
            self: @ContractState, plan_id: u256, data_type: IPFSDataType,
        ) -> IPFSData {
            let data_type_u8 = match data_type {
                IPFSDataType::UserProfile => 0_u8,
                IPFSDataType::PlanDetails => 1_u8,
                IPFSDataType::MediaMessages => 2_u8,
                IPFSDataType::ActivityLog => 3_u8,
                IPFSDataType::Notifications => 4_u8,
                IPFSDataType::Wallets => 5_u8,
            };
            let hash = self.plan_ipfs_hashes.entry(plan_id).entry(data_type_u8).read();
            IPFSData { hash, timestamp: get_block_timestamp(), data_type }
        }

        fn store_kyc_details(ref self: ContractState, ipfs_hash: ByteArray) -> bool {
            let caller = get_caller_address();

            // Ensure the user doesn't already have KYC details stored
            let existing_hash = self.kyc_details_uri.entry(caller).read();
            assert(existing_hash.len() == 0, 'KYC details already exist');

            assert(ipfs_hash.len() > 0, 'IPFS hash cannot be empty');

            self.kyc_details_uri.entry(caller).write(ipfs_hash.clone());

            self
                .record_user_activity(
                    caller, ActivityType::ProfileUpdate, 'KYC details stored', '', '',
                );

            self
                .emit(
                    Event::KYCDetailsStored(
                        KYCDetailsStored {
                            user: caller, ipfs_hash: ipfs_hash, timestamp: get_block_timestamp(),
                        },
                    ),
                );

            true
        }

        fn update_kyc_details(ref self: ContractState, new_ipfs_hash: ByteArray) -> ByteArray {
            let caller = get_caller_address();

            // Get existing KYC details
            let old_hash = self.kyc_details_uri.entry(caller).read();
            assert(old_hash.len() > 0, 'No existing KYC details');

            assert(new_ipfs_hash.len() > 0, 'IPFS hash cannot be empty');

            assert(old_hash != new_ipfs_hash, 'New hash must be different');

            self.kyc_details_uri.entry(caller).write(new_ipfs_hash.clone());

            self
                .record_user_activity(
                    caller, ActivityType::ProfileUpdate, 'KYC details updated', '', '',
                );

            self
                .emit(
                    Event::KYCDetailsUpdated(
                        KYCDetailsUpdated {
                            user: caller,
                            old_ipfs_hash: old_hash,
                            new_ipfs_hash: new_ipfs_hash.clone(),
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );

            new_ipfs_hash
        }

        fn get_kyc_details(self: @ContractState, user: ContractAddress) -> ByteArray {
            let caller = get_caller_address();

            // Users can only access their own KYC details unless they're admin
            let admin = self.admin.read();
            assert(caller == user || caller == admin, 'Unauthorized KYC access');

            self.kyc_details_uri.entry(user).read()
        }

        fn has_kyc_details(self: @ContractState, user: ContractAddress) -> bool {
            let kyc_hash = self.kyc_details_uri.entry(user).read();
            kyc_hash.len() > 0
        }

        fn delete_kyc_details(ref self: ContractState) -> bool {
            let caller = get_caller_address();

            let existing_hash = self.kyc_details_uri.entry(caller).read();
            assert(existing_hash.len() > 0, 'No KYC details to delete');

            let empty_hash: ByteArray = "";
            self.kyc_details_uri.entry(caller).write(empty_hash);

            self
                .record_user_activity(
                    caller, ActivityType::SecurityChange, 'KYC details deleted', '', '',
                );

            self
                .emit(
                    Event::KYCDetailsDeleted(
                        KYCDetailsDeleted { user: caller, timestamp: get_block_timestamp() },
                    ),
                );

            true
        }
    }
}
