use starknet::ContractAddress;

// Constants for plan settings
const MAX_BENEFICIARIES: u8 = 10_u8;
const MAX_ADDITIONAL_FILES: u8 = 3_u8;
const MAX_FILE_SIZE: u64 = 10485760_u64; // 10MB in bytes

#[derive(Drop, Serde)]
pub struct PlanOverview {
    pub plan_id: u256,
    pub name: felt252,
    pub description: felt252,
    pub tokens_transferred: Array<TokenInfo>,
    pub transfer_date: u64,
    pub inactivity_period: u64,
    pub multi_signature_enabled: bool,
    pub creation_date: u64,
    pub status: PlanStatus,
    pub total_value: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TokenInfo {
    pub address: ContractAddress,
    pub symbol: felt252,
    pub chain: felt252,
    pub balance: u256,
    pub price: u256,
}

#[derive(Drop, Serde)]
pub struct BeneficiaryInfo {
    name: felt252,
    email: felt252,
    wallet_address: ContractAddress,
    token_allocations: Array<TokenAllocation>,
    nft_allocations: Array<NFTAllocation>,
    personal_message: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TokenAllocation {
    token: ContractAddress,
    percentage: u8,
    estimated_value: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct NFTAllocation {
    contract_address: ContractAddress,
    token_id: u256,
    collection_name: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct PlanConditions {
    transfer_date: u64,
    inactivity_period: u64,
    multi_signature_required: bool,
    required_approvals: u8,
}

#[derive(Drop, Serde)]
pub struct MediaMessage {
    file_hash: felt252,
    file_name: felt252,
    file_type: felt252,
    file_size: u64,
    recipients: Array<ContractAddress>,
    upload_date: u64,
}

#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub enum PlanStatus {
    Draft,
    Active,
    Executed,
    Cancelled,
}

#[derive(Copy, Drop, Serde)]
pub enum PlanSection {
    BasicInformation: (),
    Beneficiaries: (),
    MediaAndRecipients: (),
}

#[starknet::interface]
pub trait IInheritXPlan<TContractState> {
    // Plan Overview Management
    fn get_plan_section(self: @TContractState, plan_id: u256, section: PlanSection) -> PlanOverview;

    fn get_beneficiaries_details(self: @TContractState, plan_id: u256) -> Array<SimpleBeneficiary>;

    fn get_beneficiary_allocations(
        self: @TContractState, plan_id: u256, beneficiary_id: u32,
    ) -> BeneficiaryAllocation;

    fn get_media_messages(self: @TContractState, plan_id: u256) -> Array<MediaMessage>;

    // Plan Actions
    fn execute_plan_now(ref self: TContractState, plan_id: u256);
    fn override_plan(ref self: TContractState, plan_id: u256);
    fn delete_plan(ref self: TContractState, plan_id: u256);

    // Plan Creation Steps
    fn create_plan(
        ref self: TContractState,
        name: felt252,
        description: felt252,
        selected_tokens: Array<TokenInfo>,
        code: u256,
        beneficiary: SimpleBeneficiary,
    ) -> felt252;

    fn add_beneficiaries(
        ref self: TContractState, plan_id: u256, beneficiaries: Array<SimpleBeneficiary>,
    );

    fn set_plan_conditions(ref self: TContractState, plan_id: u256, conditions: PlanConditions);

    fn add_media_messages(ref self: TContractState, plan_id: u256, messages: Array<MediaMessage>);

    // Plan Validation
    fn validate_plan_status(self: @TContractState, plan_id: u256) -> bool;
    fn can_execute_plan(self: @TContractState, plan_id: u256) -> bool;
    fn can_override_plan(self: @TContractState, plan_id: u256) -> bool;
    fn can_delete_plan(self: @TContractState, plan_id: u256) -> bool;

    // Media Preview
    fn get_media_preview_url(self: @TContractState, plan_id: u256, file_hash: felt252) -> felt252;

    // Beneficiary Management
    fn add_beneficiary(
        ref self: TContractState,
        plan_id: u256,
        name: felt252,
        email: felt252,
        address: ContractAddress,
    ) -> felt252;

    fn get_beneficiary(
        self: @TContractState, plan_id: u256, address: ContractAddress,
    ) -> SimpleBeneficiary;

    // Media Management
    fn add_media_file(
        ref self: TContractState,
        plan_id: u256,
        file_hash: felt252,
        file_name: felt252,
        file_type: felt252,
        file_size: u64,
        recipients: Array<ContractAddress>,
    );

    // Statistics and Totals
    fn get_total_plans(self: @TContractState) -> u256;
    fn get_total_assets(self: @TContractState) -> u256;
    fn get_total_activity(self: @TContractState) -> u64;
    fn get_plan_total_beneficiaries(self: @TContractState, plan_id: u256) -> u32;
}
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct SimpleBeneficiary {
    pub id: u32, // Unique identifier for the beneficiary
    pub name: felt252,
    pub email: felt252,
    pub wallet_address: ContractAddress,
    pub personal_message: felt252,
}

// Separate structs for token and NFT allocations
#[derive(Drop, Serde)]
pub struct BeneficiaryAllocation {
    pub beneficiary_id: u32,
    pub token_allocations: Array<TokenAllocation>,
    pub nft_allocations: Array<NFTAllocation>,
}