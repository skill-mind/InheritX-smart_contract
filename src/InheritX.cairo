#[starknet::contract]
pub mod InheritX {
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use crate::interfaces::IInheritX::{AssetAllocation, IInheritX, InheritancePlan};
    use crate::types::{ActivityRecord, ActivityType, SimpleBeneficiary};

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
        pub protocol_fee: u256, // Base points (1 = 0.01%)
        pub min_guardians: u8, // Minimum guardians per plan
        pub max_guardians: u8, // Maximum guardians per plan
        pub min_timelock: u64, // Minimum timelock period in seconds
        pub max_timelock: u64, // Maximum timelock period in seconds
        pub is_paused: bool, // Protocol pause state
        // Protocol statistics for analytics
        pub total_plans: u256,
        pub active_plans: u256,
        pub claimed_plans: u256,
        pub total_value_locked: u256,
        pub total_fees_collected: u256,
        // Plan details
        plan_asset_owner: Map<u256, ContractAddress>, // plan_id -> asset_owner
        plan_creation_date: Map<u256, u64>, // plan_id -> creation_date
        plan_transfer_date: Map<u256, u64>, // plan_id -> transfer_date
        plan_message: Map<u256, felt252>, // plan_id -> message
        plan_total_value: Map<u256, u256>, // plan_id -> total_value
        // Beneficiaries
        plan_beneficiaries_count: Map<u256, u32>, // plan_id -> beneficiaries_count
        plan_beneficiaries: Map<(u256, u32), ContractAddress>, // (plan_id, index) -> beneficiary
        is_beneficiary: Map<
            (u256, ContractAddress), bool,
        >, // (plan_id, beneficiary) -> is_beneficiary
        // Record user activities
        user_activities: Map<ContractAddress, Map<u256, ActivityRecord>>,
        user_activities_pointer: Map<ContractAddress, u256>,
        // Beneficiary to Recipient Mapping
        pub funds: Map<u256, SimpleBeneficiary>,
        pub plans_id: u256,
        // Dummy Mapping For transfer
        balances: Map<ContractAddress, u256>,
        deployed: bool,
        // Inheritance Plan Mapping
        inheritance_plans: Map<u256, InheritancePlan>,
        plan_guardians: Map<(u256, u8), ContractAddress>,
        plan_assets: Map<(u256, u8), AssetAllocation>,
        plan_guardian_count: Map<u256, u8>,
        plan_asset_count: Map<u256, u8>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BeneficiaryAdded: BeneficiaryAdded,
        ActivityRecordEvent: ActivityRecordEvent,
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
    struct ActivityRecordEvent {
        user: ContractAddress,
        activity_id: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) { // Initialize contract state:
        // 1. Set admin address
        self.admin.write(get_caller_address()); // Assuming the caller is the admin
        // 2. Set default protocol parameters:
        self.protocol_fee.write(50);
        self.min_guardians.write(1);
        self.max_guardians.write(5);
        self.min_timelock.write(604800);
        self.max_timelock.write(31536000);
        // 3. Initialize all statistics to 0
        self.total_plans.write(0);
        self.active_plans.write(0);
        self.claimed_plans.write(0);
        self.total_value_locked.write(0);
        self.total_fees_collected.write(0);
        // 4. Set is_paused to false
        self.is_paused.write(false);
        self.deployed.write(true);
    }

    #[abi(embed_v0)]
    impl IInheritXImpl of IInheritX<ContractState> { // Contract Management Functions
        // Initialize a new claim with a claim code
        /// Initiates a claim for an inheritance plan by creating a new beneficiary entry
        /// and processing the payout.
        ///
        /// @param name - The name of the beneficiary.
        /// @param email - The email address of the beneficiary.
        /// @param beneficiary - The wallet address of the beneficiary.
        /// @param personal_message - A message associated with the inheritance.
        /// @param amount - The amount allocated for the beneficiary.
        /// @param claim_code - A unique code assigned to the claim.
        /// @param amountt - (Unused) Duplicate of `amount`, consider removing if unnecessary.
        /// @return felt252 - Returns `1` on successful claim initiation.
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

            // Store the beneficiary details in the `funds` mapping
            self.funds.write(inheritance_id, new_beneficiary);

            // Increment the plan ID after storing the new entry

            self.plans_id.write(inheritance_id + 1);

            // Transfer funds as part of the claim process
            self.transfer_funds(get_contract_address(), amount);

            // Return success code
            inheritance_id
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
            // Retrieve the claim details from storage
            let mut claim = self.funds.read(inheritance_id);

            // Ensure the claim has not been collected before
            assert(!claim.claim_status, 'You have already made a claim');

            // Verify that the correct beneficiary is making the claim
            assert((claim.wallet_address == beneficiary), 'Not your claim');

            // Verify that the provided claim code matches the stored one
            assert((claim.code == claim_code), 'Invalid claim code');

            // Mark the claim as collected
            claim.claim_status = true;

            // Transfer the funds to the beneficiary
            self.transfer_funds(beneficiary, claim.amount);

            // Update the claim in storage after modifying it
            self.funds.write(inheritance_id, claim);
            // Return success status
            true
        }

        fn create_inheritance_plan(
            ref self: ContractState,
            time_lock_period: u64,
            required_guardians: u8,
            guardians: Array<ContractAddress>,
            assets: Array<AssetAllocation>,
        ) -> u256 {
            // Validate parameters
            let min_timelock = self.min_timelock.read();
            let max_timelock = self.max_timelock.read();
            let min_guardians = self.min_guardians.read();
            let max_guardians = self.max_guardians.read();

            // Ensure timelock period is within valid range
            assert(time_lock_period >= min_timelock, 'Timelock too short');
            assert(time_lock_period <= max_timelock, 'Timelock too long');

            // Ensure guardian count is within valid range
            let guardian_count = guardians.len();
            assert(guardian_count >= min_guardians.into(), 'Too few guardians');
            assert(guardian_count <= max_guardians.into(), 'Too many guardians');
            assert(
                required_guardians <= guardian_count.try_into().unwrap(),
                'Invalid required guardians',
            );
            assert(required_guardians > 0, 'Need at least 1 guardian');

            // Ensure we have at least one asset
            let asset_count = assets.len();
            assert(asset_count > 0, 'No assets specified');

            // Calculate total value of plan
            let mut total_value: u256 = 0;
            let mut i: u32 = 0;
            while i < asset_count {
                let asset = assets.at(i);
                total_value += *asset.amount;
                i += 1;
            };

            // Create new plan ID
            let plan_id = self.plans_id.read();
            self.plans_id.write(plan_id + 1);

            // Create the inheritance plan
            let new_plan = InheritancePlan {
                owner: get_caller_address(),
                time_lock_period,
                required_guardians,
                is_active: true,
                is_claimed: false,
                total_value,
            };

            // Store the plan
            self.inheritance_plans.write(plan_id, new_plan);

            // Store guardians
            let mut guardian_index: u8 = 0;
            i = 0;
            while i < guardian_count {
                self.plan_guardians.write((plan_id, guardian_index), *guardians.at(i));
                guardian_index += 1;
                i += 1;
            };
            self.plan_guardian_count.write(plan_id, guardian_count.try_into().unwrap());

            // Store assets
            let mut asset_index: u8 = 0;
            i = 0;
            while i < asset_count {
                self.plan_assets.write((plan_id, asset_index), *assets.at(i));
                asset_index += 1;
                i += 1;
            };
            self.plan_asset_count.write(plan_id, asset_count.try_into().unwrap());

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
                let asset = assets.at(i);
                // In production, this would call actual token transfers
                self.transfer_funds(get_contract_address(), *asset.amount);
                i += 1;
            };

            plan_id
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

        fn get_total_plans(self: @ContractState) -> u256 {
            let total_plans = self.total_plans.read();
            total_plans
        }

        fn is_beneficiary(self: @ContractState, plan_id: u256, address: ContractAddress) -> bool {
            self.is_beneficiary.read((plan_id, address))
        }

        fn set_plan_transfer_date(ref self: ContractState, plan_id: u256, date: u64) {
            self.plan_transfer_date.write(plan_id, date);
        }
        /// Records the activity of a user in the system
        /// @param self - The contract state.
        /// @param user - The user to record for.
        /// @param activity_type - the activity type (enum ActivityType).
        /// @param details - The details of the activity.
        /// @param ip_address - The ip address of where the activity is carried out from.
        /// @param device_info - The device information of where the activity is carried out from.
        /// @returns `u256` The id of the recorded activity.
        fn record_user_activity(
            ref self: ContractState,
            user: ContractAddress,
            activity_type: ActivityType,
            details: felt252,
            ip_address: felt252,
            device_info: felt252,
        ) -> u256 {
            // fetch the user activities map
            let user_activities = self.user_activities.entry(user);
            // get the user's current activity map pointer (tracking the map index)
            let current_pointer = self.user_activities_pointer.entry(user).read();
            // create a record from the given details
            let record = ActivityRecord {
                timestamp: get_block_timestamp(), activity_type, details, ip_address, device_info,
            };
            // create the next pointer
            let next_pointer = current_pointer + 1;
            // add the record to the position of the next pointer
            user_activities.entry(next_pointer).write(record);
            // Save the next pointer
            self.user_activities_pointer.entry(user).write(next_pointer);
            // Emit event
            self.emit(ActivityRecordEvent { user, activity_id: next_pointer });
            // return the id of the activity (next_pointer)
            next_pointer
        }

        /// Gets the user activity from the particular id
        /// @param self - The contract state.
        /// @param user - The user
        /// @param activity_id - the id of the activities saved in the contract storage.
        /// @returns ActivityRecord - The record of the activity.
        fn get_user_activity(
            ref self: ContractState, user: ContractAddress, activity_id: u256,
        ) -> ActivityRecord {
            self.user_activities.entry(user).entry(activity_id).read()
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
