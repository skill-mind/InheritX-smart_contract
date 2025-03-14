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
struct BeneficiaryInfo {
    name: felt252,
    email: felt252,
    wallet_address: ContractAddress,
    token_allocations: Array<TokenAllocation>,
    nft_allocations: Array<NFTAllocation>,
    personal_message: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct TokenAllocation {
    token: ContractAddress,
    percentage: u8,
    estimated_value: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct NFTAllocation {
    contract_address: ContractAddress,
    token_id: u256,
    collection_name: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct PlanConditions {
    transfer_date: u64,
    inactivity_period: u64,
    multi_signature_required: bool,
    required_approvals: u8,
}

#[derive(Drop, Serde)]
struct MediaMessage {
    file_hash: felt252,
    file_name: felt252,
    file_type: felt252,
    file_size: u64,
    recipients: Array<ContractAddress>,
    upload_date: u64,
}

#[derive(Copy, Drop, Serde)]
pub enum PlanStatus {
    Draft: (),
    Active: (),
    Executed: (),
    Cancelled: (),
}

#[derive(Copy, Drop, Serde)]
enum PlanSection {
    BasicInformation: (),
    Beneficiaries: (),
    MediaAndRecipients: (),
}

#[starknet::interface]
trait IInheritXPlan<TContractState> {
    // Plan Overview Management
    fn get_plan_section(self: @TContractState, plan_id: u256, section: PlanSection) -> PlanOverview;

    fn get_beneficiaries_details(self: @TContractState, plan_id: u256) -> Array<BeneficiaryInfo>;

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
    ) -> u256;

    fn add_beneficiaries(
        ref self: TContractState, plan_id: u256, beneficiaries: Array<BeneficiaryInfo>,
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
}

// Events
#[event]
#[derive(Drop, starknet::Event)]
enum PlanEvent {
    PlanCreated: PlanCreated,
    BeneficiariesAdded: BeneficiariesAdded,
    ConditionsSet: ConditionsSet,
    MediaAdded: MediaAdded,
    PlanExecuted: PlanExecuted,
    PlanOverridden: PlanOverridden,
    PlanDeleted: PlanDeleted,
}

#[derive(Drop, starknet::Event)]
struct PlanCreated {
    plan_id: u256,
    creator: ContractAddress,
    name: felt252,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct BeneficiariesAdded {
    plan_id: u256,
    beneficiary_count: u32,
    total_allocation: u256,
}

#[derive(Drop, starknet::Event)]
struct ConditionsSet {
    plan_id: u256,
    transfer_date: u64,
    inactivity_period: u64,
    multi_sig_enabled: bool,
}

#[derive(Drop, starknet::Event)]
struct MediaAdded {
    plan_id: u256,
    file_count: u32,
    total_size: u64,
}

#[derive(Drop, starknet::Event)]
struct PlanExecuted {
    plan_id: u256,
    executor: ContractAddress,
    timestamp: u64,
    total_value_transferred: u256,
}

#[derive(Drop, starknet::Event)]
struct PlanOverridden {
    plan_id: u256,
    overrider: ContractAddress,
    timestamp: u64,
    reason: felt252,
}

#[derive(Drop, starknet::Event)]
struct PlanDeleted {
    plan_id: u256,
    deleter: ContractAddress,
    timestamp: u64,
}
