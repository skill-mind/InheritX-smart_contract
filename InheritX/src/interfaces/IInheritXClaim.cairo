use starknet::ContractAddress;

#[derive(Drop, Serde)]
struct ClaimOverview {
    claim_id: u256,
    plan_id: u256,
    beneficiary: ContractAddress,
    status: ClaimStatus,
    submission_date: u64,
    verification_deadline: u64,
    total_value: u256,
    tokens_to_receive: Array<TokenClaim>,
    nfts_to_receive: Array<NFTClaim>,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct TokenClaim {
    token: ContractAddress,
    symbol: felt252,
    amount: u256,
    value_usd: u256,
    chain: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct NFTClaim {
    contract_address: ContractAddress,
    token_id: u256,
    collection_name: felt252,
    estimated_value: u256,
}

#[derive(Copy, Drop, Serde)]
struct VerificationDocument {
    document_type: felt252,
    document_hash: felt252,
    submission_date: u64,
    verification_status: VerificationStatus,
    verifier: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
enum ClaimStatus {
    Pending: (),
    VerificationRequired: (),
    Approved: (),
    Rejected: (),
    Executed: (),
    Expired: (),
}

#[derive(Copy, Drop, Serde)]
enum VerificationStatus {
    Pending: (),
    Approved: (),
    Rejected: (),
    NeedsMoreInfo: (),
}

#[derive(Copy, Drop, Serde)]
enum ClaimAction {
    Submit: (),
    VerifyIdentity: (),
    UploadDocuments: (),
    AcceptTerms: (),
    ReceiveAssets: (),
}

#[starknet::interface]
pub trait IInheritXClaim<TContractState> {
    // Claim Overview
    fn get_claim_overview(self: @TContractState, claim_id: u256) -> ClaimOverview;
    fn get_beneficiary_claims(
        self: @TContractState, beneficiary: ContractAddress,
    ) -> Array<ClaimOverview>;
    fn get_claim_status(self: @TContractState, claim_id: u256) -> ClaimStatus;
    fn get_required_actions(self: @TContractState, claim_id: u256) -> Array<ClaimAction>;

    // Claim Process
    fn initiate_claim(
        ref self: TContractState, plan_id: u256, beneficiary: ContractAddress,
    ) -> u256;

    fn submit_verification_documents(
        ref self: TContractState, claim_id: u256, documents: Array<VerificationDocument>,
    );

    fn verify_identity(ref self: TContractState, claim_id: u256, verification_data: Array<felt252>);

    fn accept_terms(ref self: TContractState, claim_id: u256);

    fn execute_claim(ref self: TContractState, claim_id: u256);

    // Guardian Actions
    fn approve_claim(
        ref self: TContractState, claim_id: u256, guardian: ContractAddress, notes: felt252,
    );

    fn reject_claim(
        ref self: TContractState, claim_id: u256, guardian: ContractAddress, reason: felt252,
    );

    fn request_additional_verification(
        ref self: TContractState,
        claim_id: u256,
        guardian: ContractAddress,
        requirements: Array<felt252>,
    );

    // Validation
    fn validate_claim_eligibility(
        self: @TContractState, plan_id: u256, beneficiary: ContractAddress,
    ) -> bool;
    fn can_execute_claim(self: @TContractState, claim_id: u256) -> bool;
    fn get_verification_requirements(self: @TContractState, claim_id: u256) -> Array<felt252>;
}

// Events
#[event]
#[derive(Drop, starknet::Event)]
enum ClaimEvent {
    ClaimInitiated: ClaimInitiated,
    DocumentsSubmitted: DocumentsSubmitted,
    IdentityVerified: IdentityVerified,
    TermsAccepted: TermsAccepted,
    ClaimApproved: ClaimApproved,
    ClaimRejected: ClaimRejected,
    ClaimExecuted: ClaimExecuted,
    VerificationRequested: VerificationRequested,
}

#[derive(Drop, starknet::Event)]
struct ClaimInitiated {
    claim_id: u256,
    plan_id: u256,
    beneficiary: ContractAddress,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct DocumentsSubmitted {
    claim_id: u256,
    document_count: u32,
    submission_date: u64,
}

#[derive(Drop, starknet::Event)]
struct IdentityVerified {
    claim_id: u256,
    verifier: ContractAddress,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct TermsAccepted {
    claim_id: u256,
    beneficiary: ContractAddress,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct ClaimApproved {
    claim_id: u256,
    guardian: ContractAddress,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct ClaimRejected {
    claim_id: u256,
    guardian: ContractAddress,
    reason: felt252,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct ClaimExecuted {
    claim_id: u256,
    beneficiary: ContractAddress,
    total_value: u256,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct VerificationRequested {
    claim_id: u256,
    guardian: ContractAddress,
    requirements: Array<felt252>,
    deadline: u64,
}
