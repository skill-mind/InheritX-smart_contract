use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct InheritancePlan {
    owner: ContractAddress,
    time_lock_period: u64,
    required_guardians: u8,
    is_active: bool,
    is_claimed: bool,
    total_value: u256,
}

#[derive(Drop, Serde)]
pub struct AssetAllocation {
    pub token: ContractAddress,
    pub amount: u256,
    pub percentage: u8,
}

#[starknet::interface]
pub trait IInheritX<TContractState> {
    // Contract Management
    fn initialize(
        ref self: TContractState,
        security_contract: ContractAddress,
        plan_contract: ContractAddress,
        claim_contract: ContractAddress,
        profile_contract: ContractAddress,
        dashboard_contract: ContractAddress,
        swap_contract: ContractAddress,
    );

    fn upgrade_contract(
        ref self: TContractState, contract_type: felt252, new_address: ContractAddress,
    );


    // Protocol Configuration
    fn set_protocol_fee(ref self: TContractState, new_fee: u256);
    fn set_min_guardians(ref self: TContractState, min_count: u8);
    fn set_timelock_limits(ref self: TContractState, min_period: u64, max_period: u64);
    fn pause_protocol(ref self: TContractState);
    fn unpause_protocol(ref self: TContractState);
    fn is_protocol_paused(self: @TContractState) -> bool;

    // Plan Management
    fn create_inheritance_plan(
        ref self: TContractState,
        beneficiaries: Array<ContractAddress>,
        asset_allocations: Array<(ContractAddress, u256, u8)>,
        time_lock_period: u64,
        required_guardians: u8,
    ) -> u256;

    // Plan Query Functions
    fn get_plan_owner(self: @TContractState, plan_id: u256) -> ContractAddress;
    fn get_plan_timelock(self: @TContractState, plan_id: u256) -> u64;
    fn get_plan_guardians_required(self: @TContractState, plan_id: u256) -> u8;
    fn get_plan_status(
        self: @TContractState, plan_id: u256,
    ) -> (bool, bool); // (is_active, is_claimed)
    fn get_plan_value(self: @TContractState, plan_id: u256) -> u256;
    fn get_plan_beneficiaries(self: @TContractState, plan_id: u256) -> Array<ContractAddress>;
    fn get_plan_allocations(
        self: @TContractState, plan_id: u256,
    ) -> Array<(ContractAddress, u256, u8)>;
    fn get_beneficiary_plans(self: @TContractState, beneficiary: ContractAddress) -> Array<u256>;
    fn get_owner_plans(self: @TContractState, owner: ContractAddress) -> Array<u256>;
    fn is_plan_active(self: @TContractState, plan_id: u256) -> bool;

    // Guardian Management
    fn add_guardian(ref self: TContractState, plan_id: u256, guardian: ContractAddress);
    fn remove_guardian(ref self: TContractState, plan_id: u256, guardian: ContractAddress);

    // Asset Management
    fn update_beneficiary_allocation(
        ref self: TContractState,
        plan_id: u256,
        beneficiary: ContractAddress,
        new_allocation: (ContractAddress, u256, u8),
    );

    fn swap_allocated_assets(
        ref self: TContractState,
        plan_id: u256,
        from_token: ContractAddress,
        to_token: ContractAddress,
        amount: u256,
    );

    // Plan Lifecycle
    fn activate_plan(ref self: TContractState, plan_id: u256);
    fn deactivate_plan(ref self: TContractState, plan_id: u256);

    // Claims
    fn claim_inheritance(ref self: TContractState, plan_id: u256);
    fn approve_claim(ref self: TContractState, plan_id: u256, beneficiary: ContractAddress);

    // Security & Activity
    fn record_activity(ref self: TContractState);
    // fn get_last_activity(self: @TContractState, owner: ContractAddress) -> u64;


    // // Protocol Stats
    // fn get_total_plans(self: @TContractState) -> u256;
    // fn get_total_active_plans(self: @TContractState) -> u256;
    // fn get_total_claimed_plans(self: @TContractState) -> u256;
    // fn get_protocol_fees(self: @TContractState) -> u256;
}
