use core::array::ArrayTrait;
use core::pedersen::PedersenTrait;
use core::zeroable;
use starknet::contract_address::ContractAddress;

#[starknet::contract]
pub mod InheritX {
    use core::array::ArrayTrait;
    use core::hash::HashStateExTrait;
    use core::num::traits::Zero;
    use core::pedersen::HashState;
    use core::poseidon::{PoseidonTrait, poseidon_hash_span};
    use core::traits::Into;
    use starknet::storage::{
        Map, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{
        ContractAddress, contract_address_const, get_block_number, get_block_timestamp,
        get_caller_address, get_contract_address,
    };
    use crate::interfaces::IInheritX::{AssetAllocation, IInheritX, InheritancePlan};
    use crate::types::{
        ActivityRecord, ActivityType, MediaMessage, NotificationSettings, NotificationStruct,
        PlanConditions, PlanOverview, PlanSection, PlanStatus, SecuritySettings, SimpleBeneficiary,
        TokenAllocation, TokenInfo, UserProfile, UserRole, VerificationStatus, Wallet,
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
        plan_asset_owner: Map<u256, ContractAddress>,
        plan_creation_date: Map<u256, u64>,
        plan_transfer_date: Map<u256, u64>,
        plan_message: Map<u256, felt252>,
        plan_total_value: Map<u256, u256>,
        plan_beneficiaries_count: Map<u256, u32>,
        plan_beneficiaries: Map<(u256, u32), ContractAddress>,
        is_beneficiary: Map<(u256, ContractAddress), bool>,
        user_activities: Map<ContractAddress, Map<u256, ActivityRecord>>,
        user_activities_pointer: Map<ContractAddress, u256>,
        pub funds: Map<u256, SimpleBeneficiary>,
        pub plans_id: u256,
        balances: Map<ContractAddress, u256>,
        deployed: bool,
        inheritance_plans: Map<u256, InheritancePlan>,
        plan_guardians: Map<(u256, u8), ContractAddress>,
        plan_assets: Map<(u256, u8), AssetAllocation>,
        plan_guardian_count: Map<u256, u8>,
        plan_asset_count: Map<u256, u8>,
        // storage mappings for plan_name and description
        plan_name: Map<u256, felt252>,
        plan_description: Map<u256, felt252>,
        plans_count: u256,
        beneficiary_details: Map<
            (u256, ContractAddress), SimpleBeneficiary,
        >, // (plan_id, beneficiary) -> beneficiary details
        // Plan details
        plan_status: Map<u256, PlanStatus>, // plan_id -> status
        plan_conditions: Map<u256, PlanConditions>, // plan_id -> conditions
        // Tokens
        plan_tokens_count: Map<u256, u32>, // plan_id -> tokens_count
        plan_tokens: Map<(u256, u32), TokenInfo>, // (plan_id, index) -> token_info
        token_allocations: Map<
            (u256, ContractAddress, ContractAddress), TokenAllocation,
        >, // (plan_id, beneficiary, token) -> allocation
        // Media messages
        plan_media_messages: Map<(u256, u32), MediaMessage>, // (plan_id, message_index) -> message
        media_message_recipients: Map<
            (u256, u32, u32), ContractAddress,
        >, // (plan_id, message_index, recipient_index) -> address
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
        user_wallets: Map<(ContractAddress, u256), Wallet>,
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

    //     #[derive(Copy, Drop, Serde)]

    //     #[derive(Copy, Drop, Serde)]ze

    //  enum VerificationStatus {
    //     Unverified,
    //     PendingVerification,
    //     Verified,
    //     Rejected,
    // }

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
        self.total_plans.write(0); // Initialize total_plans to 0
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
            let plan_id = self.plans_id.read();
            self.plans_id.write(plan_id + 1);

            // Store plan details
            self.plan_name.write(plan_id + 1, plan_name);
            self.plan_description.write(plan_id + 1, description);
            self.plan_asset_owner.write(plan_id + 1, get_caller_address());
            self.plan_creation_date.write(plan_id + 1, get_block_timestamp());
            self.plan_total_value.write(plan_id + 1, total_value);

            let new_plan = InheritancePlan {
                owner: get_caller_address(),
                // time_lock_period: 0,
                // required_guardians: 0,
                is_active: true,
                is_claimed: false,
                total_value,
                plan_name,
                description,
            };
            self.write_to_inheritance(plan_id + 1, new_plan);
            // Store assets (tokens)
            let mut asset_index: u8 = 0;
            i = 0;
            while i < asset_count {
                self.plan_assets.write((plan_id + 1, asset_index), *tokens.at(i));
                asset_index += 1;
                i += 1;
            }
            self.write_to_asset_count(plan_id + 1, asset_count);

            // Store beneficiaries
            let mut beneficiary_index: u32 = 0;
            i = 0;
            while i < beneficiary_count {
                let beneficiary = *pick_beneficiaries.at(i);
                self.plan_beneficiaries.write((plan_id + 1, beneficiary_index), beneficiary);
                self.is_beneficiary.write((plan_id + 1, beneficiary), true);
                beneficiary_index += 1;
                i += 1;
            }
            self.write_to_beneficiary_count(plan_id + 1, beneficiary_count);

            // Update protocol statistics
            let current_total_plans = self.total_plans.read();
            self.total_plans.write(current_total_plans + 1);
            let current_active_plans = self.active_plans.read();
            self.active_plans.write(current_active_plans + 1);
            let current_tvl = self.total_value_locked.read();
            self.total_value_locked.write(current_tvl + total_value);

            self.write_plan_status(plan_id + 1, PlanStatus::Active);

            // Transfer assets to contract
            i = 0;
            while i < asset_count {
                let asset = tokens.at(i);
                self.transfer_funds(get_contract_address(), *asset.amount);
                i += 1;
            }

            // Generate new plan ID
            self.plans_id.write(plan_id + 1);
            let plan_id = self.plans_id.read();
            plan_id
        }

        fn write_plan_status(ref self: ContractState, plan_id: u256, status: PlanStatus) {
            self.plan_status.write(plan_id, PlanStatus::Active);
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
            let user_activities = self.user_activities.entry(user);
            let current_pointer = self.user_activities_pointer.entry(user).read();
            let record = ActivityRecord {
                timestamp: get_block_timestamp(), activity_type, details, ip_address, device_info,
            };
            let next_pointer = current_pointer + 1;
            user_activities.entry(next_pointer).write(record);
            self.user_activities_pointer.entry(user).write(next_pointer);
            self.emit(ActivityRecordEvent { user, activity_id: next_pointer });
            next_pointer
        }

        fn get_user_activity(
            ref self: ContractState, user: ContractAddress, activity_id: u256,
        ) -> ActivityRecord {
            self.user_activities.entry(user).entry(activity_id).read()
        }

        fn get_profile(ref self: ContractState, address: ContractAddress) -> UserProfile {
            let user = self.user_profiles.read(address);
            user
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

            // Generate random code
            // let code = self.generate_verification_code(user);
            let code = 123456;

            // store code with expiry
            let expiry = get_block_timestamp() + 600; // 10 minutes in seconds
            self.verification_code.write(user, code);
            self.verification_expiry.write(user, expiry);
            self.verification_attempts.write(user, 0);

            // send code to user via SMS or email
            code
        }
        fn check_expiry(ref self: ContractState, user: ContractAddress) -> bool {
            let expiry = self.verification_expiry.read(user);
            assert(get_block_timestamp() < expiry, 'Code expired');
            true
        }

        fn complete_verififcation(ref self: ContractState, user: ContractAddress, code: felt252) {
            // check attempts
            let attempts = self.verification_attempts.read(user);
            assert(attempts < 3, 'Maximum attempts reached');

            // check expiry
            let check_expiry = self.check_expiry(user);
            assert(check_expiry == true, 'Check expiry failed');
            // verify code
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

        /// Check verification status
        fn is_verified(self: @ContractState, user: ContractAddress) -> bool {
            self.verification_status.read(user)
        }

        /// Adds a media message to a specific plan.
        /// @param self - The contract state.
        /// @param plan_id - The ID of the plan.
        /// @param media_type - The type of media (e.g., 0 for image, 1 for video).
        /// @param media_content - The content of the media (e.g., IPFS hash or URL as felt252).
        fn add_beneficiary(
            ref self: ContractState,
            plan_id: u256,
            name: felt252,
            email: felt252,
            address: ContractAddress,
        ) -> felt252 {
            let asset_owner = self.plan_asset_owner.read(plan_id);
            assert(asset_owner != address, 'Invalid plan_id');

            let caller = starknet::get_caller_address();
            assert(caller == asset_owner, 'Caller is not the asset owner');

            assert(self.plan_transfer_date.read(plan_id) == 0, 'Plan is already executed');

            assert(!address.is_zero(), 'Invalid beneficiary address');
            assert(!self.is_beneficiary.read((plan_id, address)), 'Adlready a beneficiary');

            assert(name != 0, 'Name cannot be empty');
            assert(email != 0, 'Email cannot be empty');

            let current_count: u32 = self.plan_beneficiaries_count.read(plan_id);
            let max_allowed: u32 = self.max_guardians.read().into();
            assert(current_count < max_allowed, 'Exceeds max beneficiaries');

            self.plan_beneficiaries.write((plan_id, current_count), address);
            self.is_beneficiary.write((plan_id, address), true);
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
            self.plan_asset_owner.write(plan_id, owner);
        }

        fn set_max_guardians(ref self: ContractState, max_guardian_number: u8) {
            self.max_guardians.write(max_guardian_number);
        }

        fn get_plan_beneficiaries_count(self: @ContractState, plan_id: u256) -> u32 {
            let count = self.plan_beneficiaries_count.read(plan_id);
            count
        }

        fn get_plan_beneficiaries(
            self: @ContractState, plan_id: u256, index: u32,
        ) -> ContractAddress {
            let beneficiary = self.plan_beneficiaries.read((plan_id, index));
            beneficiary
        }

        fn get_activity_history(
            self: @ContractState, user: ContractAddress, start_index: u256, page_size: u256,
        ) -> Array<ActivityRecord> {
            assert(page_size > 0, 'Page size must be positive');
            let total_activity_count = self.user_activities_pointer.entry(user).read();

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
            self.is_beneficiary.read((plan_id, address))
        }

        fn set_plan_transfer_date(ref self: ContractState, plan_id: u256, date: u64) {
            self.plan_transfer_date.write(plan_id, date);
        }
        fn get_activity_history_length(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_activities_pointer.entry(user).read()
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
            let user_notification = self.get_all_notification_preferences(user);
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
            let notification = self.user_notifications.read(user);
            notification
        }

        fn get_plan_section(
            self: @ContractState, plan_id: u256, section: PlanSection,
        ) -> PlanOverview {
            // Assert that the plan_id exists
            let current_total_plans = self.total_plans.read();
            assert(plan_id < current_total_plans, 'Plan does not exist');

            // Get all tokens for this plan
            let tokens_count = self.plan_tokens_count.read(plan_id);
            let mut tokens = ArrayTrait::new();

            for i in 0..tokens_count {
                let token_info = self.plan_tokens.read((plan_id, i));
                tokens.append(token_info);
            }

            // Create a PlanOverview struct with basic details
            let mut plan_overview = PlanOverview {
                plan_id: plan_id,
                name: self.plan_name.read(plan_id),
                description: self.plan_description.read(plan_id),
                tokens_transferred: tokens,
                transfer_date: self.plan_transfer_date.read(plan_id),
                inactivity_period: self.plan_conditions.read(plan_id).inactivity_period,
                multi_signature_enabled: self
                    .plan_conditions
                    .read(plan_id)
                    .multi_signature_required,
                creation_date: self.plan_creation_date.read(plan_id),
                status: self.plan_status.read(plan_id),
                total_value: self.plan_total_value.read(plan_id),
                beneficiaries: ArrayTrait::new(),
                media_messages: ArrayTrait::new(),
            };

            // Fill section-specific details using if statements instead of match
            if section == PlanSection::BasicInformation { // Basic information is already filled
            } else if section == PlanSection::Beneficiaries {
                let beneficiaries_count = self.plan_beneficiaries_count.read(plan_id);
                let mut beneficiaries: Array<SimpleBeneficiary> = ArrayTrait::new();

                for i in 0..beneficiaries_count {
                    let beneficiary_address = self.plan_beneficiaries.read((plan_id, i));
                    let beneficiary_details = self
                        .beneficiary_details
                        .read((plan_id, beneficiary_address));
                    beneficiaries.append(beneficiary_details);
                }
                plan_overview.beneficiaries = beneficiaries;
            } else if section == PlanSection::MediaAndRecipients {
                let media_messages_count = self.plan_media_messages_count.read(plan_id);
                let mut media_messages_result = ArrayTrait::new();

                for i in 0..media_messages_count {
                    let media_message = self.plan_media_messages.read((plan_id, i));
                    let mut recipients = ArrayTrait::new();

                    // Read each recipient from separate storage
                    for j in 0..media_message.recipients_count {
                        let recipient = self.media_message_recipients.read((plan_id, i, j));
                        recipients.append(recipient);
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
            // user.address,
            user.username = ' ';
            user.address = contract_address_const::<0>();
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
            // Get the caller's address
            let caller = get_caller_address();

            // Check if the profile exists
            let mut profile = self.user_profiles.read(caller);

            // Ensure the profile belongs to the caller
            assert(profile.address == caller || profile.address.is_zero(), 'Not authorized');

            // Update profile fields
            profile.address = caller;
            profile.username = username;
            profile.email = email;
            profile.full_name = full_name;
            profile.profile_image = profile_image;
            profile.notification_settings = notification_settings;
            profile.security_settings = security_settings;
            profile.last_active = get_block_timestamp();

            // If this is a new profile, set creation date
            if profile.created_at.is_zero() {
                profile.created_at = get_block_timestamp();
                // Set default role for new profiles
                profile.role = UserRole::User;
                profile.verification_status = VerificationStatus::Unverified;
            }

            // Save updated profile
            self.user_profiles.write(caller, profile);

            // Record this activity
            self._record_activity(caller, ActivityType::ProfileUpdate, 'Profile updated');

            // Update notification settings if provided
            let ns = notification_settings;
            match ns {
                NotificationSettings::Nil => (),
                _ => self._update_notification_settings(caller, ns),
            }

            true
        }

        // Helper function to update notification settings
        fn _update_notification_settings(
            ref self: ContractState, user: ContractAddress, settings: NotificationSettings,
        ) {
            // Convert the enum to a struct for storage
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

        // Helper function to record user activity
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
                ip_address: 0, // We can't get IP in Cairo, so using 0
                device_info: 0 // We can't get device info in Cairo, so using 0
            };

            // Fix: Use entry() pattern for nested maps
            self.user_activities.entry(user).entry(current_pointer).write(activity);
            self.user_activities_pointer.write(user, next_pointer);
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

        // Wallet Management Functions
        fn add_wallet(
            ref self: ContractState, wallet: ContractAddress, wallet_type: felt252,
        ) -> bool {
            assert!(wallet != starknet::contract_address_const::<0>(), "Invalid wallet address");
            let user = get_caller_address();
            let length = self.user_wallets_length.read(user);

            //
            let mut wallet_exists = false;
            let mut i = 0;
            while i < length {
                let w = self.user_wallets.read((user, i));
                if w.address == wallet {
                    wallet_exists = true;
                    break;
                }
                i += 1;
            }
            assert!(!wallet_exists, "Wallet already exists");

            let new_wallet = Wallet {
                address: wallet,
                is_primary: length == 0,
                wallet_type,
                added_at: get_block_timestamp(),
            };
            self.user_wallets.write((user, length), new_wallet);
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
                let w = self.user_wallets.read((user, i));
                if w.address == wallet {
                    wallet_found = true;
                    wallet_index = i;
                    break;
                }
                i += 1;
            }
            assert!(wallet_found, "Wallet not found");

            i = 0;
            while i < length {
                let mut w = self.user_wallets.read((user, i));
                w.is_primary = (i == wallet_index);
                self.user_wallets.write((user, i), w);
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
                let wallet = self.user_wallets.read((user, i));
                core::array::ArrayTrait::append(ref wallets, wallet);
                i += 1;
            }
            wallets
        }

        fn is_plan_valid(self: @ContractState, plan_id: u256) -> bool {
            // Check if plan exists
            let current_total_plans = self.total_plans.read();
            if plan_id >= current_total_plans {
                return false;
            }

            self.is_valid_plan_status(plan_id);

            self.plan_has_been_claimed(plan_id);

            self.plan_is_active(plan_id);

            self.plan_has_assets(plan_id);

            self.check_beneficiary_plan(plan_id);

            // Plan is valid if it passed all checks
            true
        }


        fn is_valid_plan_status(self: @ContractState, plan_id: u256) -> bool {
            // Check plan status - only active plans are valid
            let status = self.plan_status.read(plan_id);
            if status != PlanStatus::Active {
                return false;
            }
            return true;
        }

        fn plan_has_been_claimed(self: @ContractState, plan_id: u256) -> bool {
            // Retrieve plan from storage
            let plan = self.inheritance_plans.read(plan_id);

            // Check if plan has been claimed
            if plan.is_claimed {
                return false;
            }
            return true;
        }

        fn plan_is_active(self: @ContractState, plan_id: u256) -> bool {
            // Retrieve plan from storage
            let plan = self.inheritance_plans.read(plan_id);
            // Check if plan has been activated
            if !plan.is_active {
                return false;
            }
            return true;
        }

        fn plan_has_assets(self: @ContractState, plan_id: u256) -> bool {
            // Check if plan has assets
            let asset_count = self.plan_asset_count.read(plan_id);
            if asset_count == 0 {
                return false;
            }
            return true;
        }
        fn check_beneficiary_plan(self: @ContractState, plan_id: u256) -> bool {
            // Check if plan has beneficiaries
            let beneficiaries_count = self.plan_beneficiaries_count.read(plan_id);
            if beneficiaries_count == 0 {
                return false;
            }
            // Plan is valid if it passed all checks
            true
        }
    }
}

