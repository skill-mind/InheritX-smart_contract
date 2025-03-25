#[starknet::contract]
pub mod InheritX {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePathEntry, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use crate::interfaces::IInheritX::{AssetAllocation, IInheritX, InheritancePlan};
    use crate::types::{SimpleBeneficiary, ActivityType, ActivityRecord};

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

        // Plan management
        plans_count: u256,

        // New storage mapping to track the preview URLs for media files in each plan.
        plan_media_preview_urls: Map<(u256, felt252), felt252>, // (plan_id, file_hash) -> preview_url
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


    #[constructor]
    fn constructor(ref self: ContractState) { // Initialize contract state:
        // 1. Set admin address
        // 2. Set default protocol parameters:
        //    - protocol_fee = 50 (0.5%)
        //    - min_guardians = 1
        //    - max_guardians = 5
        //    - min_timelock = 7 days
        //    - max_timelock = 365 days
        // 3. Initialize all statistics to 0
        // 4. Set is_paused to false
        self.deployed.write(true);
        self.total_plans.write(0); // Initialize total_plans to 0
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

            // Increment the total plans count
            let total_plans = self.total_plans.read();
            self.total_plans.write(total_plans + 1);

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

        fn get_total_plans(self: @ContractState) -> u256 {
            self.total_plans.read()
        }

        fn get_media_preview_url(
            self: @ContractState, plan_id: u256, file_hash: felt252
        ) -> felt252 {
            // 1. Assert plan_id exists
            let plans_count = self.plans_count.read();
            assert(plan_id < plans_count, 'Plan does not exist');
    
            // 2. Assert file_hash is not zero
            assert(file_hash != 0, 'Invalid file hash');
    
            // 3. Retrieve preview URL from storage
            let preview_url = self.plan_media_preview_urls.read((plan_id, file_hash));
            assert(preview_url != 0, 'File not found in plan');
    
            // 4. Return the preview URL
            preview_url
        }
    }
}
