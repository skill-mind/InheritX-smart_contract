#[starknet::contract]
pub mod InheritX {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use crate::interfaces::IInheritX::{AssetAllocation, IInheritX, InheritancePlan};
    use crate::types::{
        SimpleBeneficiary, ActivityType, ActivityRecord, UserProfile, VerificationStatus, UserRole,
        SecuritySettings, NotificationSettings,
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
        plan_names: Map<u256, felt252>,
        plan_descriptions: Map<u256, felt252>,
        user_profiles: Map<ContractAddress, UserProfile>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ActivityRecordEvent: ActivityRecordEvent,
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
            }
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
            }
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
            }

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

            // Increment the total plans count
            let total_plans = self.total_plans.read();
            self.total_plans.write(total_plans + 1);

            // Transfer funds as part of the claim process
            self.transfer_funds(get_contract_address(), amount);
            inheritance_id
        }
        /// Creates a new user profile and stores it in the contract state.
        ///
        /// @param self - Reference to the contract state.
        /// @param username - The user's chosen username.
        /// @param email - The user's email address.
        /// @param full_name - The user's full name.
        /// @param profile_image - A reference to the user's profile image.
        /// @return bool - Returns `true` if the profile is created successfully.
        fn create_profile(
            ref self: ContractState,
            username: felt252,
            email: felt252,
            full_name: felt252,
            profile_image: felt252,
        ) -> bool {
            // Create a new UserProfile with the provided values and defaults.
            // We assume `self.contract_address` returns the caller's or contract's address.
            // For connected_wallets, notification_settings, and security_settings, we assume
            // there are default constructors or values available.
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

            // Store the new profile in the contract state's user_profiles mapping.
            // Here we assume `user_profiles` is a mapping from an address to UserProfile.
            self.user_profiles.write(new_profile.address, new_profile);

            true
        }

        /// Allows a beneficiary to collect their claim.
        /// @param self - The contract state.
        /// @param inheritance_id - The ID of the inheritance claim.
        /// @param beneficiary - The wallet address of the beneficiary.
        /// @param claim_code - The unique code to verify the claim.
        /// @returns `true` if the claim is successfully collected, otherwise `false`.
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
            self.plan_beneficiaries_count.read(plan_id)
        }

        fn get_plan_beneficiaries(
            self: @ContractState, plan_id: u256, index: u32,
        ) -> ContractAddress {
            self.plan_beneficiaries.read((plan_id, index))
        }

        fn get_total_plans(self: @ContractState) -> u256 {
            self.total_plans.read()
        }

        fn is_beneficiary(self: @ContractState, plan_id: u256, address: ContractAddress) -> bool {
            self.is_beneficiary.read((plan_id, address))
        }

        fn set_plan_transfer_date(ref self: ContractState, plan_id: u256, date: u64) {
            self.plan_transfer_date.write(plan_id, date);
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


        // Dummy Functions
        /// Retrieves the details of a claim using the inheritance ID.
        /// @param self - The contract state.
        /// @param inheritance_id - The ID of the inheritance claim.
        /// @returns The `SimpleBeneficiary` struct containing the claim details.
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
    }
}
