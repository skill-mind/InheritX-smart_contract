#[starknet::contract]
pub mod InheritX {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait,
    };
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use crate::interfaces::IInheritX::{AssetAllocation, IInheritX, InheritancePlan};
    use crate::types::{SimpleBeneficiary, PlanOverview, PlanSection, TokenInfo,
         PlanConditions, PlanStatus, MediaMessage, TokenAllocation};

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
        // Beneficiary to Recipient Mapping
        funds: Map<u256, SimpleBeneficiary>,
        plans_id: u256,
        // Dummy Mapping For transfer
        balances: Map<ContractAddress, u256>,
        deployed: bool,
        // Plan management
        plans_count: u256,
        // Beneficiaries
        plan_beneficiaries_count: Map<u256, u32>, // plan_id -> beneficiaries_count
        plan_beneficiaries: Map<(u256, u32), ContractAddress>, // (plan_id, index) -> beneficiary address
        is_beneficiary: Map<(u256, ContractAddress), bool>, // (plan_id, beneficiary) -> is_beneficiary
        beneficiary_details: Map<(u256, ContractAddress), SimpleBeneficiary>, // (plan_id, beneficiary) -> beneficiary details

        // Plan details
        plan_asset_owner: Map<u256, ContractAddress>, // plan_id -> asset_owner
        plan_name: Map<u256, felt252>, // plan_id -> name
        plan_description: Map<u256, felt252>, // plan_id -> description
        plan_creation_date: Map<u256, u64>, // plan_id -> creation_date
        plan_transfer_date: Map<u256, u64>, // plan_id -> transfer_date
        plan_total_value: Map<u256, u256>, // plan_id -> total_value
        plan_status: Map<u256, PlanStatus>, // plan_id -> status
        plan_conditions: Map<u256, PlanConditions>, // plan_id -> conditions

        // Tokens
        plan_tokens_count: Map<u256, u32>, // plan_id -> tokens_count
        plan_tokens: Map<(u256, u32), TokenInfo>, // (plan_id, index) -> token_info
        token_allocations: Map<(u256, ContractAddress, ContractAddress), TokenAllocation>, // (plan_id, beneficiary, token) -> allocation

        // Media messages
        plan_media_messages_count: Map<u256, u32>, // plan_id -> media_messages_count
        plan_media_messages: Map<(u256, u32), MediaMessage>, // (plan_id, index) -> media_message

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

        /// Retrieves a specific section of a plan with detailed information.
        /// 
        /// @param self - The contract state.
        /// @param plan_id - The ID of the plan to retrieve.
        /// @param section - The specific section of the plan to retrieve (BasicInformation, Beneficiaries, or MediaAndRecipients).
        /// @returns A PlanOverview object containing the requested section details.
        fn get_plan_section(self: @ContractState, plan_id: u256, section: PlanSection) -> PlanOverview {
        // Assert that the plan_id exists
        assert(self.plans_count.read() > plan_id, 'Plan does not exist');

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
            name: self.plan_name.read(plan_id),       // Read from dedicated name field
            description: self.plan_description.read(plan_id), // Read from dedicated description field
            tokens_transferred: tokens,
            transfer_date: self.plan_transfer_date.read(plan_id),
            inactivity_period: self.plan_conditions.read(plan_id).inactivity_period,
            multi_signature_enabled: self.plan_conditions.read(plan_id).multi_signature_required,
            creation_date: self.plan_creation_date.read(plan_id),
            status: self.plan_status.read(plan_id),
            total_value: self.plan_total_value.read(plan_id),
            beneficiaries: ArrayTrait::new(),
            media_messages: ArrayTrait::new(),
        };
        // Fill section-specific details
        match section {
            PlanSection::BasicInformation => {
                // Basic information is already filled
            },
            PlanSection::Beneficiaries => {
                // Get the number of beneficiaries
                let beneficiaries_count = self.plan_beneficiaries_count.read(plan_id);

                // Iterate through each beneficiary index
                let mut beneficiaries = ArrayTrait::new();
                for i in 0..beneficiaries_count {
                    let beneficiary_address = self.plan_beneficiaries.read((plan_id, i));
                    let beneficiary = SimpleBeneficiary {
                        id: i.into(),
                        name: Default::default(),
                        email: Default::default(),
                        wallet_address: beneficiary_address,
                        personal_message: Default::default(),
                        amount: Default::default(),
                        code: Default::default(),
                        claim_status: Default::default(),
                        benefactor: self.plan_asset_owner.read(plan_id),
                    };
                    beneficiaries.append(beneficiary);
                }
                plan_overview.beneficiaries = beneficiaries;
            },
            PlanSection::MediaAndRecipients => {
                // Get the number of media messages
                let media_messages_count = self.plan_media_messages_count.read(plan_id);

                // Iterate through each media message index
                let mut media_messages = array![];
                for i in 0..media_messages_count {
                    let media_message = self.plan_media_messages.read((plan_id, i));
                    media_messages.append(media_message);
                }
                plan_overview.media_messages = media_messages;
            },
        }

        // Return the PlanOverview
        plan_overview

        }
    }
}
