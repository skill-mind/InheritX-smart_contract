#[starknet::contract]
pub mod InheritxPlan {
    use core::array::ArrayTrait;
    use core::option::OptionTrait;
    use core::traits::TryInto;
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use crate::interfaces::IInheritXPlan::IInheritXPlan;
    // Import the types from the interface
    use crate::interfaces::IInheritXPlan::{
        BeneficiaryAllocation, MediaMessage, NFTAllocation, PlanConditions, PlanOverview,
        PlanSection, PlanStatus, SimpleBeneficiary, TokenAllocation, TokenInfo,
    };

    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct NFTInfo {
        pub contract_address: ContractAddress,
        pub token_id: u256,
        pub collection_name: felt252,
        pub estimated_value: u256,
    }

    #[storage]
    struct Storage {
        // Contract admin/owner
        owner: ContractAddress,
        // Plan management
        plans_count: u256,
        // Asset owner to plans mapping
        owner_plans: Map<(ContractAddress, u256), u256>, // (asset_owner, index) -> plan_id
        owner_plans_count: Map<ContractAddress, u256>,
        // Plan details
        plan_asset_owner: Map<u256, ContractAddress>, // plan_id -> asset_owner
        plan_status: Map<u256, PlanStatus>, // plan_id -> status
        plan_creation_date: Map<u256, u64>, // plan_id -> creation_date
        plan_transfer_date: Map<u256, u64>, // plan_id -> transfer_date
        plan_message: Map<u256, felt252>, // plan_id -> message
        plan_total_value: Map<u256, u256>, // plan_id -> total_value
        // Beneficiaries
        plan_beneficiaries_count: Map<u256, u32>, // plan_id -> beneficiaries_count
        plan_beneficiaries: Map<(u256, u32), SimpleBeneficiary>, // (plan_id, index) -> beneficiary
        is_beneficiary: Map<
            (u256, ContractAddress), bool,
        >, // (plan_id, beneficiary) -> is_beneficiary
        max_beneficiaries: u32, // Maximum number of beneficiaries allowed per plan
        // Tokens
        plan_tokens_count: Map<u256, u32>, // plan_id -> tokens_count
        plan_tokens: Map<(u256, u32), TokenInfo>, // (plan_id, index) -> token_info
        // NFTs
        plan_nfts_count: Map<u256, u32>, // plan_id -> nfts_count
        plan_nfts: Map<(u256, u32), NFTInfo>, // (plan_id, index) -> nft_info
        // Claim codes
        plan_claim_code: Map<u256, u256>, // plan_id -> claim_code
        claim_codes: Map<u256, u256>, // claim_code -> plan_id
        // Claim contract reference
        claim_contract: ContractAddress,
    }



    // Implementation of the interface
    #[abi(embed_v0)]
    impl InheritXPlanImpl of IInheritXPlan<ContractState> {
        fn get_beneficiaries_details(
            self: @ContractState, plan_id: u256,
        ) -> Array<SimpleBeneficiary> {
            // TODO: Implement get_beneficiaries_details
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Get the number of beneficiaries for this plan (plan_beneficiaries_count)
            // 3. Create an empty array to store beneficiary information
            // 4. Iterate through each beneficiary index (0 to beneficiaries_count-1)
            //    a. Get beneficiary address from plan_beneficiaries mapping
            //    b. Create a SimpleBeneficiary struct with details
            //    c. Add the SimpleBeneficiary to the array
            // 5. Return the array of beneficiaries
            panic!("Not implemented")
        }

        fn get_media_messages(self: @ContractState, plan_id: u256) -> Array<MediaMessage> {
            // TODO: Implement get_media_messages
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Get the number of media messages for this plan
            // 3. Create an empty array to store media messages
            // 4. Iterate through each media message index
            //    a. Get media message details from storage
            //    b. Create a MediaMessage struct
            //    c. Add the MediaMessage to the array
            // 5. Return the array of media messages
            panic!("Not implemented")
        }

        fn get_plan_section(
            self: @ContractState, plan_id: u256, section: PlanSection,
        ) -> PlanOverview {
            // TODO: Implement get_plan_section
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Create a PlanOverview struct
            // 3. Fill in basic plan details (plan_id, name, description, etc.)
            // 4. Based on the section parameter, include additional details:
            //    - If BasicInformation: Include basic plan details
            //    - If Beneficiaries: Include beneficiary information
            //    - If MediaAndRecipients: Include media messages
            // 5. Return the PlanOverview
            panic!("Not implemented")
        }


        fn get_beneficiary_allocations(
            self: @ContractState, plan_id: u256, beneficiary_id: u32,
        ) -> BeneficiaryAllocation {
            // TODO: Implement get_beneficiary_allocations
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Assert beneficiary_id is valid (beneficiary_id <
            // self.plan_beneficiaries_count.read(plan_id))
            // 3. Get beneficiary address from plan_beneficiaries mapping
            // 4. Create empty arrays for token and NFT allocations
            // 5. Iterate through tokens assigned to this plan
            //    a. For each token, check if allocated to this beneficiary
            //    b. If allocated, create TokenAllocation and add to array
            // 6. Iterate through NFTs assigned to this plan
            //    a. For each NFT, check if allocated to this beneficiary
            //    b. If allocated, create NFTAllocation and add to array
            // 7. Create and return BeneficiaryAllocation with the arrays
            panic!("Not implemented")
        }


        fn execute_plan_now(ref self: ContractState, plan_id: u256) {
            // TODO: Implement execute_plan_now
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Assert caller is authorized (caller == self.owner.read() || caller ==
            // self.plan_asset_owner.read(plan_id))
            // 3. Assert plan is in valid state for execution (not already executed)
            // 4. For each beneficiary:
            //    a. Transfer allocated tokens to beneficiary
            //    b. Transfer allocated NFTs to beneficiary
            // 5. Update plan status to Executed
            // 6. Record execution timestamp
            // 7. Emit PlanExecuted event
            panic!("Not implemented")
        }

        fn override_plan(ref self: ContractState, plan_id: u256) {
            // TODO: Implement override_plan
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Assert caller is the asset owner (caller == self.plan_asset_owner.read(plan_id))
            // 3. Assert plan is in valid state for override (not executed)
            // 4. Assert override conditions are met (can_override_plan returns true)
            // 5. Update plan status to Cancelled
            // 6. Emit PlanOverridden event
            panic!("Not implemented")
        }

        fn delete_plan(ref self: ContractState, plan_id: u256) {
            // TODO: Implement delete_plan
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Assert caller is the asset owner (caller == self.plan_asset_owner.read(plan_id))
            // 3. Assert plan is in valid state for deletion (not executed)
            // 4. Assert deletion conditions are met (can_delete_plan returns true)
            // 5. Remove plan data from storage:
            //    a. Clear beneficiary mappings
            //    b. Clear token mappings
            //    c. Clear NFT mappings
            //    d. Clear plan details
            // 6. Update owner_plans mapping
            // 7. Emit PlanDeleted event
            panic!("Not implemented")
        }

        fn create_plan(
            ref self: ContractState,
            name: felt252,
            description: felt252,
            selected_tokens: Array<TokenInfo>,
            code: u256,
            beneficiary: SimpleBeneficiary,
        ) -> felt252 {
            // TODO: Implement create_plan
            // 1. Assert name and description are not empty
            // 2. Assert selected_tokens array is not empty
            // 3. Assert code is valid and unique (not already used)
            //    a. Assert code > 0
            //    b. Assert claim_codes.read(code) == 0 (code not already used)
            // 4. Generate new plan_id (increment plans_count)
            // 5. Store plan details:
            //    a. Set plan_asset_owner to caller
            //    b. Set plan_creation_date to current timestamp
            //    c. Store name, description in plan_message
            // 6. Store selected tokens:
            //    a. Set plan_tokens_count
            //    b. Store each token in plan_tokens mapping
            //    c. Calculate and store total value
            // 7. Add initial beneficiary:
            //    a. Assert beneficiary.wallet_address is not zero
            //    b. Assert is_beneficiary.read((plan_id, beneficiary.wallet_address)) == false (not
            //    already a beneficiary)
            //    c. Set plan_beneficiaries_count to 1
            //    d. Store beneficiary address in plan_beneficiaries
            //    e. Set is_beneficiary mapping to true
            // 8. Store claim code:
            //    a. Set plan_claim_code
            //    b. Set claim_codes mapping
            // 9. Update owner_plans mapping
            // 10. Emit PlanCreated event
            // 11. Return plan_id as felt252
            panic!("Not implemented")
        }

        fn add_beneficiaries(
            ref self: ContractState, plan_id: u256, beneficiaries: Array<SimpleBeneficiary>,
        ) {
    // 1. Assert plan_id exists (plan_id < self.plans_count.read())
    assert(plan_id < self.plans_count.read(), 'Invalid plan_id');

    // 2. Assert caller is the asset owner (caller == self.plan_asset_owner.read(plan_id))
    let caller = starknet::get_caller_address();
    let asset_owner = self.plan_asset_owner.read(plan_id);
    assert(caller == asset_owner, 'Caller is not the asset owner');

    // 3. Assert plan is in valid state for modification (not executed)
    let plan_status = self.plan_status.read(plan_id);
    assert(plan_status != PlanStatus::Executed, "Plan is already executed".into());

    // 4. Assert beneficiaries array is not empty
    assert(beneficiaries.len() > 0, "Beneficiaries array is empty".into());

    // 5. Assert adding beneficiaries won't exceed MAX_BENEFICIARIES
    let current_count = self.plan_beneficiaries_count.read(plan_id);
    let new_count = current_count + beneficiaries.len();
    assert(new_count <= self.max_beneficiaries.read(), "Exceeds maximum beneficiaries".into());

    // 6. For each beneficiary in the array:
    for beneficiary in beneficiaries.span() {
        // a. Assert beneficiary.wallet_address is not zero
        assert(beneficiary.wallet_address != 0, "Invalid beneficiary address".into());

        // b. Assert is_beneficiary.read((plan_id, beneficiary.wallet_address)) == false (not already a beneficiary)
        let is_already_beneficiary = self.is_beneficiary.read((plan_id, *beneficiary.wallet_address));
        assert(!is_already_beneficiary, "Beneficiary already exists".into());

        // c. Get current beneficiary count
        let beneficiary_count = self.plan_beneficiaries_count.read(plan_id);

        // d. Store beneficiary in plan_beneficiaries
        self.plan_beneficiaries.insert((plan_id, beneficiary_count), beneficiary);

        // e. Set is_beneficiary mapping to true
        self.is_beneficiary.insert((plan_id, beneficiary.wallet_address), true);

        // f. Increment plan_beneficiaries_count
        self.plan_beneficiaries_count.insert(plan_id, beneficiary_count + 1);


            // 7. Emit BeneficiariesAdded event
            // TODO: Define and emit the event
        }
            // TODO: Implement add_beneficiaries
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Assert caller is the asset owner (caller == self.plan_asset_owner.read(plan_id))
            // 3. Assert plan is in valid state for modification (not executed)
            // 4. Assert beneficiaries array is not empty
            // 5. Assert adding beneficiaries won't exceed MAX_BENEFICIARIES
            // 6. For each beneficiary in the array:
            //    a. Assert beneficiary.wallet_address is not zero
            //    b. Assert is_beneficiary.read((plan_id, beneficiary.wallet_address)) == false (not
            //    already a beneficiary)
            //    c. Get current beneficiary count
            //    d. Store beneficiary address in plan_beneficiaries
            //    e. Set is_beneficiary mapping to true
            //    f. Increment plan_beneficiaries_count
            // 7. Emit BeneficiariesAdded event
            
        }

        fn set_plan_conditions(ref self: ContractState, plan_id: u256, conditions: PlanConditions) {
            // TODO: Implement set_plan_conditions
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Assert caller is the asset owner (caller == self.plan_asset_owner.read(plan_id))
            // 3. Assert plan is in valid state for modification (not executed)
            // 4. Validate conditions:
            //    a. Assert transfer_date is in the future
            //    b. Assert inactivity_period is reasonable
            //    c. If multi_signature_required is true, assert required_approvals > 0
            // 5. Store conditions:
            //    a. Set plan_transfer_date
            //    b. Store inactivity_period, multi_signature_required, and required_approvals
            // 6. Emit PlanConditionsSet event
            panic!("Not implemented")
        }

        fn add_media_messages(
            ref self: ContractState, plan_id: u256, messages: Array<MediaMessage>,
        ) {
            // TODO: Implement add_media_messages
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Assert caller is the asset owner (caller == self.plan_asset_owner.read(plan_id))
            // 3. Assert plan is in valid state for modification (not executed)
            // 4. Assert messages array is not empty
            // 5. Assert adding messages won't exceed MAX_ADDITIONAL_FILES
            // 6. For each message in the array:
            //    a. Validate message:
            //       - Assert file_size <= MAX_FILE_SIZE
            //       - Assert file_hash, file_name, and file_type are not empty
            //       - Assert recipients array is not empty
            //    b. Store message in storage
            //    c. For each recipient, verify they are beneficiaries of the plan
            // 7. Emit MediaMessagesAdded event
            panic!("Not implemented")
        }

        fn validate_plan_status(self: @ContractState, plan_id: u256) -> bool {
            // TODO: Implement validate_plan_status
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Check if plan is in Active status
            // 3. Verify plan has at least one beneficiary
            // 4. Verify plan has tokens or NFTs allocated
            // 5. Verify plan conditions are set (transfer_date is not zero)
            // 6. Return true if all conditions are met, false otherwise
            panic!("Not implemented")
        }

        fn can_execute_plan(self: @ContractState, plan_id: u256) -> bool {
            // TODO: Implement can_execute_plan
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Check if plan is in Active status
            // 3. Check if current timestamp >= transfer_date
            // 4. Check if asset owner has been inactive for >= inactivity_period
            // 5. If multi_signature_required is true, check if required approvals are met
            // 6. Return true if all conditions are met, false otherwise
            panic!("Not implemented")
        }

        fn can_override_plan(self: @ContractState, plan_id: u256) -> bool {
            // TODO: Implement can_override_plan
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Check if plan is not already executed
            // 3. Check if caller is the asset owner
            // 4. Check if plan is not locked (special conditions preventing override)
            // 5. Return true if all conditions are met, false otherwise
            panic!("Not implemented")
        }

        fn can_delete_plan(self: @ContractState, plan_id: u256) -> bool {
            // TODO: Implement can_delete_plan
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Check if plan is not already executed
            // 3. Check if caller is the asset owner
            // 4. Check if plan is in Draft status or recently created
            // 5. Return true if all conditions are met, false otherwise
            panic!("Not implemented")
        }

        fn get_media_preview_url(
            self: @ContractState, plan_id: u256, file_hash: felt252,
        ) -> felt252 {
            // TODO: Implement get_media_preview_url
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Assert file_hash is not zero
            // 3. Check if the file exists for this plan
            // 4. Generate or retrieve preview URL for the file
            // 5. Return the preview URL as felt252
            panic!("Not implemented")
        }

        fn add_beneficiary(
            ref self: ContractState,
            plan_id: u256,
            name: felt252,
            email: felt252,
            address: ContractAddress,
        ) -> felt252 {
    

            // TODO: Implement add_beneficiary
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Assert caller is the asset owner (caller == self.plan_asset_owner.read(plan_id))
            // 3. Assert plan is in valid state for modification (not executed)
            // 4. Assert address is not zero
            // 5. Assert is_beneficiary.read((plan_id, address)) == false (not already a
            // beneficiary)
            // 6. Assert adding one more beneficiary won't exceed MAX_BENEFICIARIES
            // 7. Assert name and email are not empty
            // 8. Get current beneficiary count
            // 9. Create a new beneficiary ID
            // 10. Store beneficiary address in plan_beneficiaries
            // 11. Set is_beneficiary mapping to true
            // 12. Increment plan_beneficiaries_count
            // 13. Emit BeneficiaryAdded event
            // 14. Return the new beneficiary ID as felt252
            panic!("Not implemented")
        }

        fn get_beneficiary(
            self: @ContractState, plan_id: u256, address: ContractAddress,
        ) -> SimpleBeneficiary {
            // TODO: Implement get_beneficiary
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Assert address is not zero
            // 3. Assert address is a beneficiary of the plan (check is_beneficiary mapping)
            // 4. Find the beneficiary ID by iterating through plan_beneficiaries
            // 5. Retrieve beneficiary details from storage
            // 6. Create and return a SimpleBeneficiary struct with the details
            panic!("Not implemented")
        }

        fn add_media_file(
            ref self: ContractState,
            plan_id: u256,
            file_hash: felt252,
            file_name: felt252,
            file_type: felt252,
            file_size: u64,
            recipients: Array<ContractAddress>,
        ) {
            // TODO: Implement add_media_file
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Assert caller is the asset owner (caller == self.plan_asset_owner.read(plan_id))
            // 3. Assert plan is in valid state for modification (not executed)
            // 4. Validate file parameters:
            //    a. Assert file_hash is not zero
            //    b. Assert file_name and file_type are not empty
            //    c. Assert file_size <= MAX_FILE_SIZE
            //    d. Assert recipients array is not empty
            // 5. For each recipient, verify they are beneficiaries of the plan
            // 6. Create a MediaMessage struct with current timestamp as upload_date
            // 7. Store the media file in storage
            // 8. Emit MediaFileAdded event
            panic!("Not implemented")
        }

        // Statistics and Totals
        fn get_total_plans(self: @ContractState) -> u256 {
            // TODO: Implement get_total_plans
            // 1. Return the plans_count from storage
            // This function simply returns the total number of plans created in the system
            self.plans_count.read()
        }

        fn get_total_assets(self: @ContractState) -> u256 {
            // TODO: Implement get_total_assets
            // 1. Initialize a total value counter to 0
            // 2. Iterate through all plans (0 to plans_count-1)
            // 3. For each plan, add its total_value to the counter
            // 4. Return the total value
            // This function calculates the total value of all assets across all plans
            panic!("Not implemented")
        }

        fn get_total_activity(self: @ContractState) -> u64 {
            // TODO: Implement get_total_activity
            // 1. Return the activity count from storage
            // This function returns the total number of activities performed in the system
            // Activities could include plan creations, modifications, executions, etc.
            panic!("Not implemented")
        }

        fn get_plan_total_beneficiaries(self: @ContractState, plan_id: u256) -> u32 {
            // TODO: Implement get_plan_total_beneficiaries
            // 1. Assert plan_id exists (plan_id < self.plans_count.read())
            // 2. Return the plan_beneficiaries_count for the given plan_id
            // This function returns the total number of beneficiaries for a specific plan
            self.plan_beneficiaries_count.read(plan_id)
        }
    }
}
