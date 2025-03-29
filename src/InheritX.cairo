#[starknet::contract]
pub mod InheritX {
    use core::num::traits::Zero;
    use core::traits::Into;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{
        ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
        get_contract_address,
    };
    use crate::interfaces::IInheritX::{AssetAllocation, IInheritX, InheritancePlan};
    use crate::types::{
        ActivityRecord, ActivityType, NotificationSettings, NotificationStruct, SecuritySettings,
        SimpleBeneficiary, UserProfile, UserRole, VerificationStatus,
    };

    #[storage]
    struct Storage {
        total_activities: u64,
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
        plan_names: Map<u256, felt252>,
        plan_descriptions: Map<u256, felt252>,
        //Identity verification system
        verification_code: Map<ContractAddress, felt252>,
        verification_status: Map<ContractAddress, bool>,
        verification_attempts: Map<ContractAddress, u8>,
        verification_expiry: Map<ContractAddress, u64>,
        user_profiles: Map<ContractAddress, UserProfile>,
        // storage mappings for notification
        user_notifications: Map<ContractAddress, NotificationStruct>,
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
    //     #[derive(Copy, Drop, Serde)]
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
        self.total_activities.write(0);
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
            };

            // Generate new plan ID
            let plan_id = self.plans_id.read();
            self.plans_id.write(plan_id + 1);

            // Store plan details
            self.plan_names.write(plan_id, plan_name);
            self.plan_descriptions.write(plan_id, description);
            self.plan_asset_owner.write(plan_id, get_caller_address());
            self.plan_creation_date.write(plan_id, get_block_timestamp());
            self.plan_total_value.write(plan_id, total_value);

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
            self.inheritance_plans.write(plan_id, new_plan);

            // Store assets (tokens)
            let mut asset_index: u8 = 0;
            i = 0;
            while i < asset_count {
                self.plan_assets.write((plan_id, asset_index), *tokens.at(i));
                asset_index += 1;
                i += 1;
            };
            self.plan_asset_count.write(plan_id, asset_count.try_into().unwrap());

            // Store beneficiaries
            let mut beneficiary_index: u32 = 0;
            i = 0;
            while i < beneficiary_count {
                let beneficiary = *pick_beneficiaries.at(i);
                self.plan_beneficiaries.write((plan_id, beneficiary_index), beneficiary);
                self.is_beneficiary.write((plan_id, beneficiary), true);
                beneficiary_index += 1;
                i += 1;
            };
            self.plan_beneficiaries_count.write(plan_id, beneficiary_count);

            // Update protocol statistics
            let current_total_plans = self.total_plans.read();
            self.total_plans.write(current_total_plans + 1);
            let current_active_plans = self.active_plans.read();
            self.active_plans.write(current_active_plans + 1);
            let current_tvl = self.total_value_locked.read();
            self.total_value_locked.write(current_tvl + total_value);

            // Transfer assets to contract
            i = 0;
            while i < asset_count {
                let asset = tokens.at(i);
                self.transfer_funds(get_contract_address(), *asset.amount);
                i += 1;
            };

            // Return the plan ID
            plan_id
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
                timestamp: get_block_timestamp(), 
                activity_type, 
                details, 
                ip_address, 
                device_info,
            };
            let next_pointer = current_pointer + 1;
            user_activities.entry(next_pointer).write(record);
            self.user_activities_pointer.entry(user).write(next_pointer);
            
            // Increment total activities counter
            let current_total = self.total_activities.read();
            self.total_activities.write(current_total + 1);
            
            self.emit(ActivityRecordEvent { user, activity_id: next_pointer });
            next_pointer
        }

        fn get_user_activity(
            ref self: ContractState, user: ContractAddress, activity_id: u256,
        ) -> ActivityRecord {
            self.user_activities.entry(user).entry(activity_id).read()
        }

        fn get_total_activities(self: @ContractState) -> u64 {
            self.total_activities.read()
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

 feat/getTotalActivity
 feat/getTotalAsset
        fn get_total_assets_value(self: ContractState) -> u256 {
            let total_plans = self.plans_id.read();
            let mut total_value: u256 = 0;

            for inheritance_id in 0..total_plans {
                match self.funds.try_read(inheritance_id) {
                    Some(beneficiary) => {
                        if !beneficiary.claim_status {
                            total_value += beneficiary.amount;
                        }
                    }
                    None => continue, 
                }
            }
            total_value


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
 main
        fn add_beneficiary(
            ref self: ContractState,
            plan_id: u256,
            name: felt252,
            email: felt252,
            address: ContractAddress,
        ) -> felt252 {
            // 1. Check if plan exists by verifying asset owner
            let asset_owner = self.plan_asset_owner.read(plan_id);
            assert(asset_owner != address, 'Invalid plan_id');

            // 2. Verify caller is asset owner
            let caller = starknet::get_caller_address();
            assert(caller == asset_owner, 'Caller is not the asset owner');

            // 3. Check plan state
            assert(self.plan_transfer_date.read(plan_id) == 0, 'Plan is already executed');

            // 4. Validate beneficiary address
            assert(!address.is_zero(), 'Invalid beneficiary address');
            assert(!self.is_beneficiary.read((plan_id, address)), 'Adlready a beneficiary');

            // 5. Validate input data
            assert(name != 0, 'Name cannot be empty');
            assert(email != 0, 'Email cannot be empty');

            // 6. Get and validate beneficiary count
            let current_count: u32 = self.plan_beneficiaries_count.read(plan_id);
            let max_allowed: u32 = self.max_guardians.read().into();
            assert(current_count < max_allowed, 'Exceeds max beneficiaries');

            // 7. Update state
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

            // 8. Return the new beneficiary ID
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

        fn is_beneficiary(self: @ContractState, plan_id: u256, address: ContractAddress) -> bool {
            self.is_beneficiary.read((plan_id, address))
        }

        fn set_plan_transfer_date(ref self: ContractState, plan_id: u256, date: u64) {
            self.plan_transfer_date.write(plan_id, date);
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

            // Iterate and collect activity records
            let mut current_index = start_index + 1;
            loop {
                if current_index > end_index {
                    break;
                }

                let record = self.user_activities.entry(user).entry(current_index).read();
                activity_history.append(record);

                current_index += 1;
            };

            activity_history
        }

        fn get_activity_history_length(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_activities_pointer.entry(user).read()
        }

        fn get_total_plans(self: @ContractState) -> u256 {
            self.total_plans.read()
 main
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
    }
}
