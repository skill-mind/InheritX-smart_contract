#[starknet::contract]
pub mod InheritX {
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use crate::interfaces::IInheritX::{AssetAllocation, IInheritX, InheritancePlan};
    use crate::types::{
        ActivityRecord, ActivityType, NotificationSettings, SecuritySettings, SimpleBeneficiary,
        UserProfile, UserRole, VerificationStatus,
    };

    #[storage]
    struct Storage {
        // Contract addresses for component management
        admin: ContractAddress,
        security_contract: ContractAddress,
        plan_contract: ContractAddress,
        claim_contract: ContractAddress,
        profile_contract: ContractAddress,
        dashboard_contract: ContractAddress,
        swap_contract: ContractAddress,
        // Protocol configuration parameters
        protocol_fee: u256, // Base points (1 = 0.01%)
        min_guardians: u8, // Minimum guardians per plan
        max_guardians: u8, // Maximum guardians per plan
        min_timelock: u64, // Minimum timelock period in seconds
        max_timelock: u64, // Maximum timelock period in seconds
        is_paused: bool, // Protocol pause state
        // Protocol statistics for analytics
        total_plans: u256,
        active_plans: u256,
        claimed_plans: u256,
        total_value_locked: u256,
        total_fees_collected: u256,
        // Record user activities
        user_activities: Map<ContractAddress, Map<u256, ActivityRecord>>,
        user_activities_pointer: Map<ContractAddress, u256>,
        // Beneficiary to Recipient Mapping
        funds: Map<u256, SimpleBeneficiary>,
        plans_id: u256,
        // Dummy Mapping For transfer
        balances: Map<ContractAddress, u256>,
        deployed: bool,
        user_profiles: Map<ContractAddress, UserProfile>,
        plan_asset_owner: Map<u256, ContractAddress>, // plan_id -> asset_owner
        plan_creation_date: Map<u256, u64>, // plan_id -> creation_date
        plan_transfer_date: Map<u256, u64>, // plan_id -> transfer_date
        plan_message: Map<u256, felt252>, // plan_id -> message
        plan_total_value: Map<u256, u256>, // plan_id -> total_value
        // Beneficiaries
        plan_beneficiaries_count: Map<u256, u32>, // plan_id -> beneficiaries_count
        plan_beneficiaries: Map<(u256, u32), ContractAddress>, // (plan_id, index) -> beneficiary
        is_beneficiary: Map<(u256, ContractAddress), bool>,
    }

    #[derive(Drop, starknet::Event)]
    struct BeneficiaryAdded {
        plan_id: u256,
        beneficiary_id: u32,
        address: ContractAddress,
        name: felt252,
        email: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ActivityRecordEvent: ActivityRecordEvent,
        BeneficiaryAdded: BeneficiaryAdded,
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
    fn constructor(ref self: ContractState) { // Initialize contract state:
        self.deployed.write(true);
        self.total_plans.write(0); // Initialize total_plans to 0
    }

    #[abi(embed_v0)]
    impl IInheritXImpl of IInheritX<ContractState> { // Contract Management Functions
        fn create_claim(
            ref self: ContractState,
            name: felt252,
            email: felt252,
            beneficiary: ContractAddress,
            personal_message: felt252,
            amount: u256,
            claim_code: u256,
        ) -> u256 {
            let inheritance_id = self.plans_id.read(); // Use it before incrementing
            // Create a new beneficiary record
            let new_beneficiary = SimpleBeneficiary {
                id: inheritance_id,
                name,
                email,
                wallet_address: beneficiary,
                personal_message,
                amount,
                code: claim_code, // Ensure type compatibility
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
            }

            activity_history
        }

        fn get_activity_history_length(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_activities_pointer.entry(user).read()
        }

        fn get_total_plans(self: @ContractState) -> u256 {
            self.total_plans.read()
        }
    }
}
