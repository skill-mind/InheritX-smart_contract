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
        ActivityRecord, ActivityType, AssetAllocation, InheritancePlan, MediaMessage,
        NotificationSettings, NotificationStruct, PlanConditions, PlanOverview, PlanSection,
        PlanStatus, SecuritySettings, SimpleBeneficiary, TokenAllocation, TokenInfo, UserProfile,
        UserRole, VerificationStatus, Wallet,
    };

    #[storage]
    struct Storage {
        admin: ContractAddress,
        security_contract: ContractAddress,
        plan_contract: ContractAddress,
        claim_contract: ContractAddress,
        profile_contract: ContractAddress,
        dashboard_contract: ContractAddress,
        swap_contract: ContractAddress,
        pub protocol_fee: u256,
        pub min_guardians: u8,
        pub max_guardians: u8,
        pub min_timelock: u64,
        pub max_timelock: u64,
        pub is_paused: bool,
        pub total_plans: u256,
        pub active_plans: u256,
        pub claimed_plans: u256,
        pub total_value_locked: u256,
        pub total_fees_collected: u256,
        // Consolidated inheritance plans storage
        inheritance_plans: Map<u256, InheritancePlan>,
        // Nested mappings using StoragePathEntry
        plan_beneficiaries: Map<u256, Map<u32, ContractAddress>>,
        plan_beneficiaries_count: Map<u256, u32>,
        is_beneficiary: Map<u256, Map<ContractAddress, bool>>,
        #[allow(starknet::invalid_storage_member_types)]
        plan_assets: Map<u256, Map<u8, AssetAllocation>>,
        plan_asset_count: Map<u256, u8>,
        plan_guardians: Map<u256, Map<u8, ContractAddress>>,
        plan_guardian_count: Map<u256, u8>,
        user_activities: Map<ContractAddress, Map<u256, ActivityRecord>>,
        user_activities_pointer: Map<ContractAddress, u256>,
        pub funds: Map<u256, SimpleBeneficiary>,
        pub plans_id: u256,
        balances: Map<ContractAddress, u256>,
        deployed: bool,
        beneficiary_details: Map<u256, Map<ContractAddress, SimpleBeneficiary>>,
        // Plan details
        plan_status: Map<u256, PlanStatus>,
        plan_conditions: Map<u256, PlanConditions>,
        // Tokens
        plan_tokens_count: Map<u256, u32>,
        plan_tokens: Map<u256, Map<u32, TokenInfo>>,
        token_allocations: Map<u256, Map<ContractAddress, Map<ContractAddress, TokenAllocation>>>,
        // Media messages
        plan_media_messages: Map<u256, Map<u32, MediaMessage>>,
        media_message_recipients: Map<u256, Map<u32, Map<u32, ContractAddress>>>,
        plan_media_messages_count: Map<u256, u32>,
        //Identity verification system
        verification_code: Map<ContractAddress, felt252>,
        verification_status: Map<ContractAddress, bool>,
        verification_attempts: Map<ContractAddress, u8>,
        verification_expiry: Map<ContractAddress, u64>,
        user_profiles: Map<ContractAddress, UserProfile>,
        recovery_codes: Map<ContractAddress, felt252>,
        recovery_code_expiry: Map<ContractAddress, u64>,
        // storage mappings for notification
        user_notifications: Map<ContractAddress, NotificationStruct>,
        // Updated wallet-related storage mappings
        user_wallets_length: Map<ContractAddress, u256>,
        user_wallets: Map<ContractAddress, Map<u256, Wallet>>,
        user_primary_wallet: Map<ContractAddress, ContractAddress>,
        total_user_wallets: Map<ContractAddress, u256>,
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

    #[derive(Drop, starknet::Event)]
    struct BeneficiaryAdded {
        plan_id: u256,
        beneficiary_id: u32,
        address: ContractAddress,
        name: felt252,
        email: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct NotificationUpdated {
        email_notifications: bool,
        push_notifications: bool,
        claim_alerts: bool,
        plan_updates: bool,
        security_alerts: bool,
        marketing_updates: bool,
        user: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ActivityRecordEvent: ActivityRecordEvent,
        BeneficiaryAdded: BeneficiaryAdded,
        NotificationUpdated: NotificationUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct ActivityRecordEvent {
        user: ContractAddress,
        activity_id: u256,
    }

    #[derive(Drop, Serde, Hash)]
    struct RecoveryData {
        user: ContractAddress,
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

    // Helper functions outside the trait implementation
    #[generate_trait]
    impl HelperFunctions of HelperFunctionsTrait {
        fn _record_activity(
            ref self: ContractState,
            user: ContractAddress,
            activity_type: ActivityType,
            details: felt252,
        ) {
            let current_pointer = self.user_activities_pointer.read(user);
            let next_pointer = current_pointer + 1_u256;

            let activity = ActivityRecord {
                timestamp: get_block_timestamp(),
                activity_type: activity_type,
                details: details,
                ip_address: 0,
                device_info: 0,
            };

            self.user_activities.entry(user).entry(current_pointer).write(activity);
            self.user_activities_pointer.write(user, next_pointer);
        }

        fn _update_notification_settings(
            ref self: ContractState, user: ContractAddress, settings: NotificationSettings,
        ) {
            let notification_struct = match settings {
                NotificationSettings::Default => NotificationStruct {
                    email_notifications: true,
                    push_notifications: true,
                    claim_alerts: true,
                    plan_updates: true,
                    security_alerts: true,
                    marketing_updates: false,
                },
                NotificationSettings::Nil => NotificationStruct {
                    email_notifications: false,
                    push_notifications: false,
                    claim_alerts: false,
                    plan_updates: false,
                    security_alerts: false,
                    marketing_updates: false,
                },
                NotificationSettings::email_notifications => NotificationStruct {
                    email_notifications: true,
                    push_notifications: false,
                    claim_alerts: false,
                    plan_updates: false,
                    security_alerts: false,
                    marketing_updates: false,
                },
                NotificationSettings::push_notifications => NotificationStruct {
                    email_notifications: false,
                    push_notifications: true,
                    claim_alerts: false,
                    plan_updates: false,
                    security_alerts: false,
                    marketing_updates: false,
                },
                NotificationSettings::claim_alerts => NotificationStruct {
                    email_notifications: false,
                    push_notifications: false,
                    claim_alerts: true,
                    plan_updates: false,
                    security_alerts: false,
                    marketing_updates: false,
                },
                NotificationSettings::plan_updates => NotificationStruct {
                    email_notifications: false,
                    push_notifications: false,
                    claim_alerts: false,
                    plan_updates: true,
                    security_alerts: false,
                    marketing_updates: false,
                },
                NotificationSettings::security_alerts => NotificationStruct {
                    email_notifications: false,
                    push_notifications: false,
                    claim_alerts: false,
                    plan_updates: false,
                    security_alerts: true,
                    marketing_updates: false,
                },
                NotificationSettings::marketing_updates => NotificationStruct {
                    email_notifications: false,
                    push_notifications: false,
                    claim_alerts: false,
                    plan_updates: false,
                    security_alerts: false,
                    marketing_updates: true,
                },
            };

            self.user_notifications.write(user, notification_struct);
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

            // Create consolidated plan with all data
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
            };

            // Store the consolidated plan
            self.inheritance_plans.write(plan_id, new_plan);

            // Store assets using nested mapping - store as individual fields for now
            let mut asset_index: u8 = 0;
            i = 0;
            while i < asset_count {
                let asset = tokens.at(i);
                // For now, we'll store assets in a simpler way until we can resolve the Store trait
                // issue
                asset_index += 1;
                i += 1;
            }
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
            claim_code: u256,
        ) -> u256 {
            let inheritance_id = self.plans_id.read();
            let new_beneficiary = SimpleBeneficiary {
                id: inheritance_id,
                name,
                email,
                wallet_address: beneficiary,
                personal_message,
                amount,
                code: claim_code,
                claim_status: false,
                benefactor: get_caller_address(),
            };

            self.funds.write(inheritance_id, new_beneficiary);
            self.plans_id.write(inheritance_id + 1);

            let total_plans = self.total_plans.read();
            self.total_plans.write(total_plans + 1);

            self.transfer_funds(get_contract_address(), amount);

            inheritance_id
        }

        fn create_profile(
            ref self: ContractState,
            username: felt252,
            email: felt252,
            full_name: felt252,
            profile_image: felt252,
        ) -> bool {
            let new_profile = UserProfile {
                address: get_caller_address(),
                username: username,
                email: email,
                full_name: full_name,
                profile_image: profile_image,
                verification_status: VerificationStatus::Unverified,
                role: UserRole::User,
                notification_settings: NotificationSettings::Default,
                security_settings: SecuritySettings::Two_factor_enabled,
                created_at: get_block_timestamp(),
                last_active: get_block_timestamp(),
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
            let current_pointer = self.user_activities_pointer.read(user);
            let next_pointer = current_pointer + 1;

            let record = ActivityRecord {
                timestamp: get_block_timestamp(), activity_type, details, ip_address, device_info,
            };

            self.user_activities.entry(user).entry(next_pointer).write(record);
            self.user_activities_pointer.write(user, next_pointer);

            self.emit(ActivityRecordEvent { user, activity_id: next_pointer });

            next_pointer
        }

        fn get_user_activity(
            ref self: ContractState, user: ContractAddress, activity_id: u256,
        ) -> ActivityRecord {
            self.user_activities.entry(user).entry(activity_id).read()
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
            assert(!self.verification_status.read(user), 'Already verified');

            let code = 123456;
            let expiry = get_block_timestamp() + 600; // 10 minutes in seconds

            self.verification_code.write(user, code);
            self.verification_expiry.write(user, expiry);
            self.verification_attempts.write(user, 0);

            code
        }

        fn check_expiry(ref self: ContractState, user: ContractAddress) -> bool {
            let expiry = self.verification_expiry.read(user);
            assert(get_block_timestamp() < expiry, 'Code expired');
            true
        }

        fn complete_verififcation(ref self: ContractState, user: ContractAddress, code: felt252) {
            let attempts = self.verification_attempts.read(user);
            assert(attempts < 3, 'Maximum attempts reached');

            let check_expiry = self.check_expiry(user);
            assert(check_expiry == true, 'Check expiry failed');

            self.get_verification_status(code, user);
        }

        fn get_verification_status(
            ref self: ContractState, code: felt252, user: ContractAddress,
        ) -> bool {
            let stored_code = self.verification_code.read(user);
            let attempts = self.verification_attempts.read(user);

            if stored_code == code {
                self.verification_status.write(user, true);
                true
            } else {
                self.verification_attempts.write(user, attempts + 1);
                false
            }
        }

        fn is_verified(self: @ContractState, user: ContractAddress) -> bool {
            self.verification_status.read(user)
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
            assert(page_size > 0, 'Page size must be positive');
            let total_activity_count = self.user_activities_pointer.read(user);

            let mut activity_history = ArrayTrait::new();
            let end_index = if start_index + page_size > total_activity_count {
                total_activity_count
            } else {
                start_index + page_size
            };

            let mut current_index = start_index + 1;
            loop {
                if current_index > end_index {
                    break;
                }

                let record = self.user_activities.entry(user).entry(current_index).read();
                activity_history.append(record);
                current_index += 1;
            }

            activity_history
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
            self.user_activities_pointer.read(user)
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

        fn initiate_recovery(
            ref self: ContractState, user: ContractAddress, recovery_method: felt252,
        ) -> felt252 {
            let profile = self.user_profiles.read(user);
            assert(!profile.address.is_zero(), 'User profile does not exist');

            let recovery_code = self.generate_recovery_code(user);
            self.recovery_codes.write(user, recovery_code);
            self.recovery_code_expiry.write(user, get_block_timestamp() + 3600);

            self
                .record_user_activity(
                    user, ActivityType::RecoveryInitiated, recovery_method, '', '',
                );

            recovery_code
        }

        fn verify_recovery_code(
            ref self: ContractState, user: ContractAddress, recovery_code: felt252,
        ) -> bool {
            let stored_code = self.recovery_codes.read(user);
            let expiry_time = self.recovery_code_expiry.read(user);

            let is_valid = (stored_code == recovery_code && get_block_timestamp() <= expiry_time);

            if is_valid {
                self.recovery_codes.write(user, 0);
                self.recovery_code_expiry.write(user, 0);

                self
                    .record_user_activity(
                        user, ActivityType::RecoveryVerified, 'Recovery code verified', '', '',
                    );
            }

            is_valid
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
            let updated_notification = NotificationStruct {
                email_notifications: email_notifications,
                push_notifications: push_notifications,
                claim_alerts: claim_alerts,
                plan_updates: plan_updates,
                security_alerts: security_alerts,
                marketing_updates: marketing_updates,
            };

            self.user_notifications.write(user, updated_notification);

            self
                .emit(
                    Event::NotificationUpdated(
                        NotificationUpdated {
                            email_notifications,
                            push_notifications,
                            claim_alerts,
                            plan_updates,
                            security_alerts,
                            marketing_updates,
                            user,
                        },
                    ),
                );

            updated_notification
        }

        fn get_all_notification_preferences(
            ref self: ContractState, user: ContractAddress,
        ) -> NotificationStruct {
            self.user_notifications.read(user)
        }

        fn get_plan_section(
            self: @ContractState, plan_id: u256, section: PlanSection,
        ) -> PlanOverview {
            // Assert that the plan_id exists
            let current_total_plans = self.total_plans.read();
            assert(plan_id <= current_total_plans && plan_id > 0, 'Plan does not exist');

            // Get the consolidated plan data
            let plan = self.inheritance_plans.read(plan_id);

            // Get all tokens for this plan
            let tokens_count = self.plan_tokens_count.read(plan_id);
            let mut tokens = ArrayTrait::new();
            let mut i = 0;
            while i < tokens_count {
                let token_info = self.plan_tokens.entry(plan_id).entry(i).read();
                tokens.append(token_info);
                i += 1;
            }

            // Create a PlanOverview struct with basic details from consolidated plan
            let mut plan_overview = PlanOverview {
                plan_id: plan_id,
                name: plan.plan_name,
                description: plan.description,
                tokens_transferred: tokens,
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

            // Fill section-specific details
            if section == PlanSection::BasicInformation { // Basic information is already filled from consolidated plan
            } else if section == PlanSection::Beneficiaries {
                let beneficiaries_count = self.plan_beneficiaries_count.read(plan_id);
                let mut beneficiaries: Array<SimpleBeneficiary> = ArrayTrait::new();
                let mut i = 0;
                while i < beneficiaries_count {
                    let beneficiary_address = self
                        .plan_beneficiaries
                        .entry(plan_id)
                        .entry(i)
                        .read();
                    let beneficiary_details = self
                        .beneficiary_details
                        .entry(plan_id)
                        .entry(beneficiary_address)
                        .read();
                    beneficiaries.append(beneficiary_details);
                    i += 1;
                }
                plan_overview.beneficiaries = beneficiaries;
            } else if section == PlanSection::MediaAndRecipients {
                let media_messages_count = self.plan_media_messages_count.read(plan_id);
                let mut media_messages_result = ArrayTrait::new();
                let mut i = 0;
                while i < media_messages_count {
                    let media_message = self.plan_media_messages.entry(plan_id).entry(i).read();
                    let mut recipients = ArrayTrait::new();

                    // Read each recipient from separate storage
                    let mut j = 0;
                    while j < media_message.recipients_count {
                        let recipient = self
                            .media_message_recipients
                            .entry(plan_id)
                            .entry(i)
                            .entry(j)
                            .read();
                        recipients.append(recipient);
                        j += 1;
                    }

                    // Create response structure (only exists in memory)
                    let response = MediaMessageResponse {
                        file_hash: media_message.file_hash,
                        file_name: media_message.file_name,
                        file_type: media_message.file_type,
                        file_size: media_message.file_size,
                        recipients,
                        upload_date: media_message.upload_date,
                    };

                    media_messages_result.append(response);
                    i += 1;
                }
                plan_overview.media_messages = media_messages_result;
            }

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
            user.full_name = ' ';
            user.profile_image = ' ';
            user.verification_status = VerificationStatus::Nil;
            user.role = UserRole::User;
            user.notification_settings = NotificationSettings::Nil;
            user.security_settings = SecuritySettings::Nil;
            user.created_at = 0;
            user.last_active = 0;

            self.user_profiles.write(caller, user);

            true
        }

        fn update_user_profile(
            ref self: ContractState,
            username: felt252,
            email: felt252,
            full_name: felt252,
            profile_image: felt252,
            notification_settings: NotificationSettings,
            security_settings: SecuritySettings,
        ) -> bool {
            let caller = get_caller_address();
            let mut profile = self.user_profiles.read(caller);

            assert(profile.address == caller || profile.address.is_zero(), 'Not authorized');

            profile.address = caller;
            profile.username = username;
            profile.email = email;
            profile.full_name = full_name;
            profile.profile_image = profile_image;
            profile.notification_settings = notification_settings;
            profile.security_settings = security_settings;
            profile.last_active = get_block_timestamp();

            if profile.created_at.is_zero() {
                profile.created_at = get_block_timestamp();
                profile.role = UserRole::User;
                profile.verification_status = VerificationStatus::Unverified;
            }

            self.user_profiles.write(caller, profile);

            HelperFunctions::_record_activity(
                ref self, caller, ActivityType::ProfileUpdate, 'Profile updated',
            );

            let ns = notification_settings;
            match ns {
                NotificationSettings::Nil => (),
                _ => HelperFunctions::_update_notification_settings(ref self, caller, ns),
            }

            true
        }

        fn get_user_profile(self: @ContractState, user: ContractAddress) -> UserProfile {
            self.user_profiles.read(user)
        }

        fn update_security_settings(
            ref self: ContractState, new_settings: SecuritySettings,
        ) -> bool {
            let caller = get_caller_address();
            let mut profile = self.user_profiles.read(caller);

            assert(profile.address == caller, 'Profile does not exist');

            profile.security_settings = new_settings;
            self.user_profiles.write(caller, profile);

            true
        }

        fn add_wallet(
            ref self: ContractState, wallet: ContractAddress, wallet_type: felt252,
        ) -> bool {
            let zero_address: ContractAddress =
                starknet::contract_address::contract_address_const::<
                0,
            >();
            assert(wallet != zero_address, 'Invalid wallet address');

            let user = get_caller_address();
            let length = self.user_wallets_length.read(user);

            let mut wallet_exists = false;
            let mut i = 0;
            while i < length {
                let w = self.user_wallets.entry(user).entry(i).read();
                if w.address == wallet {
                    wallet_exists = true;
                    break;
                }
                i += 1;
            }

            assert(!wallet_exists, 'Wallet already exists');

            let new_wallet = Wallet {
                address: wallet,
                is_primary: length == 0,
                wallet_type,
                added_at: get_block_timestamp(),
            };

            self.user_wallets.entry(user).entry(length).write(new_wallet);
            self.user_wallets_length.write(user, length + 1);

            if length == 0 {
                self.user_primary_wallet.write(user, wallet);
            }

            let total_wallets = self.total_user_wallets.read(user);
            self.total_user_wallets.write(user, total_wallets + 1);

            true
        }

        fn set_primary_wallet(ref self: ContractState, wallet: ContractAddress) -> bool {
            let user = get_caller_address();
            let length = self.user_wallets_length.read(user);

            let mut wallet_found = false;
            let mut wallet_index = 0;
            let mut i = 0;
            while i < length {
                let w = self.user_wallets.entry(user).entry(i).read();
                if w.address == wallet {
                    wallet_found = true;
                    wallet_index = i;
                    break;
                }
                i += 1;
            }

            assert(wallet_found, 'Wallet not found');

            i = 0;
            while i < length {
                let mut w = self.user_wallets.entry(user).entry(i).read();
                w.is_primary = (i == wallet_index);
                self.user_wallets.entry(user).entry(i).write(w);
                i += 1;
            }

            self.user_primary_wallet.write(user, wallet);

            true
        }

        fn get_primary_wallet(self: @ContractState, user: ContractAddress) -> ContractAddress {
            self.user_primary_wallet.read(user)
        }

        fn get_user_wallets(self: @ContractState, user: ContractAddress) -> Array<Wallet> {
            let length = self.user_wallets_length.read(user);
            let mut wallets = ArrayTrait::new();
            let mut i = 0;
            while i < length {
                let wallet = self.user_wallets.entry(user).entry(i).read();
                core::array::ArrayTrait::append(ref wallets, wallet);
                i += 1;
            }
            wallets
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

        fn verify_claim_with_proof(
            ref self: ContractState,
            inheritance_id: u256,
            beneficiary: ContractAddress,
            claim_code: u256,
            proof: Array<felt252>,
        ) -> bool {
            // Retrieve claim data
            let claim = self.funds.read(inheritance_id);
            // Prepare data for hashing
            let mut claim_data = ArrayTrait::new();
            claim_data.append(claim.id.into());
            claim_data.append(claim.wallet_address.into());
            claim_data.append(claim.amount.into());
            claim_data.append(claim.code.into());
            claim_data.append(beneficiary.into());
            // Hash the claim data using Poseidon
            let claim_hash = poseidon_hash_span(claim_data.span());
            // Placeholder: In the future, verify the proof against claim_hash
            // For now, just return true to mock successful verification
            // TODO: Integrate actual STARK proof verification when available on Starknet
            claim_hash; // suppress unused variable warning
            proof; // suppress unused variable warning
            true
        }
    }
}
