use starknet::ContractAddress;

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

#[derive(Copy, Drop, Serde)]
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


#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct NFTInfo {
    pub contract_address: ContractAddress,
    pub token_id: u256,
    pub collection_name: felt252,
    pub estimated_value: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct SimpleBeneficiary {
    pub id: u256, // Unique identifier for the beneficiary
    pub name: felt252,
    pub email: felt252,
    pub wallet_address: ContractAddress,
    pub personal_message: felt252,
    pub amount: u256,
    pub code: u256,
    pub claim_status: bool,
    pub benefactor: ContractAddress,
}

#[derive(Drop, Serde)]
pub struct BeneficiaryAllocation {
    pub beneficiary_id: u32,
    pub token_allocations: Array<TokenAllocation>,
    pub nft_allocations: Array<NFTAllocation>,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct UserProfile {
    pub address: ContractAddress,
    pub username: felt252,
    pub email: felt252,
    pub full_name: felt252,
    pub profile_image: felt252,
    pub verification_status: VerificationStatus,
    pub role: UserRole,
    // pub connected_wallets: Array<WalletInfo>,
    pub notification_settings: NotificationSettings,
    pub security_settings: SecuritySettings,
    pub created_at: u64,
    pub last_active: u64,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct WalletInfo {
    pub address: ContractAddress,
    pub chain: felt252,
    pub wallet_type: felt252,
    pub is_primary: bool,
    pub added_date: u64,
}

#[derive(Drop, Serde, starknet::Store, Default)]
pub enum NotificationSettings {
    #[default]
    Default,
    email_notifications,
    push_notifications,
    claim_alerts,
    plan_updates,
    security_alerts,
    marketing_updates,
}

#[derive(Drop, Serde, starknet::Store, Default)]
pub enum SecuritySettings {
    #[default]
    Two_factor_enabled,
    recovery_email,
    backup_guardians,
    auto_lock_period,
    allowed_ips,
}


#[derive(Drop, Serde, starknet::Store, Default)]
pub enum VerificationStatus {
    #[default]
    Unverified,
    PendingVerification,
    Verified,
    Rejected,
}

#[derive(Drop, Serde, starknet::Store, Default)]
pub enum UserRole {
    #[default]
    User,
    Owner,
    Beneficiary,
    Guardian,
    Admin,
}
#[derive(Copy, Drop, Serde, starknet::Store)]
pub enum ActivityType {
    #[default]
    Void,
    Login: (),
    ProfileUpdate: (),
    WalletConnection: (),
    SecurityChange: (),
    PlanInteraction: (),
    ClaimInteraction: (),
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct GuardianStatus {
    pub is_active: bool,
    pub guardian_type: u8,
    pub verification_count: u32,
    pub last_verification: u64,
    pub trust_score: u8,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct VerificationRecord {
    pub verifier: ContractAddress,
    pub timestamp: u64,
    pub expiry_time: u64,
    pub verification_type: u8,
    pub data_hash: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct ActivityRecord {
    pub timestamp: u64,
    pub activity_type: ActivityType,
    pub details: felt252,
    pub ip_address: felt252,
    pub device_info: felt252,
}

 #[derive(Drop, Serde, starknet::Store)]
pub struct Wallet {
    pub address: ContractAddress,
    pub is_primary: bool,
    pub wallet_type: felt252,
    pub added_at: u64
}

