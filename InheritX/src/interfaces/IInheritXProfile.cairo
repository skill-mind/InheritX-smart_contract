use starknet::ContractAddress;

#[derive(Drop, Serde)]
struct UserProfile {
    address: ContractAddress,
    username: felt252,
    email: felt252,
    full_name: felt252,
    profile_image: felt252,
    verification_status: VerificationStatus,
    role: UserRole,
    connected_wallets: Array<WalletInfo>,
    notification_settings: NotificationSettings,
    security_settings: SecuritySettings,
    created_at: u64,
    last_active: u64,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct WalletInfo {
    address: ContractAddress,
    chain: felt252,
    wallet_type: felt252,
    is_primary: bool,
    added_date: u64,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct NotificationSettings {
    email_notifications: bool,
    push_notifications: bool,
    claim_alerts: bool,
    plan_updates: bool,
    security_alerts: bool,
    marketing_updates: bool,
}

#[derive(Drop, Serde)]
struct SecuritySettings {
    two_factor_enabled: bool,
    recovery_email: felt252,
    backup_guardians: Array<ContractAddress>,
    auto_lock_period: u64,
    allowed_ips: Array<felt252>,
}

#[derive(Copy, Drop, Serde)]
enum UserRole {
    Owner: (),
    Beneficiary: (),
    Guardian: (),
    Admin: (),
}

#[derive(Copy, Drop, Serde)]
enum VerificationStatus {
    Unverified: (),
    PendingVerification: (),
    Verified: (),
    Rejected: (),
}

#[derive(Copy, Drop, Serde)]
enum ActivityType {
    Login: (),
    ProfileUpdate: (),
    WalletConnection: (),
    SecurityChange: (),
    PlanInteraction: (),
    ClaimInteraction: (),
}

#[starknet::interface]
trait IInheritXProfile<TContractState> {
    // Profile Management
    fn get_profile(self: @TContractState, address: ContractAddress) -> UserProfile;
    fn update_profile(ref self: TContractState, profile: UserProfile);
    fn delete_profile(ref self: TContractState, address: ContractAddress);

    // Wallet Management
    fn add_wallet(ref self: TContractState, address: ContractAddress, wallet_info: WalletInfo);

    fn remove_wallet(
        ref self: TContractState, owner: ContractAddress, wallet_address: ContractAddress,
    );

    fn set_primary_wallet(
        ref self: TContractState, owner: ContractAddress, wallet_address: ContractAddress,
    );

    // Settings Management
    fn update_notification_settings(
        ref self: TContractState, address: ContractAddress, settings: NotificationSettings,
    );

    fn update_security_settings(
        ref self: TContractState, address: ContractAddress, settings: SecuritySettings,
    );

    // Verification
    fn initiate_verification(
        ref self: TContractState, address: ContractAddress, verification_data: Array<felt252>,
    );

    fn complete_verification(
        ref self: TContractState, address: ContractAddress, verification_code: felt252,
    );

    // Activity & Security
    fn record_activity(
        ref self: TContractState,
        address: ContractAddress,
        activity: ActivityType,
        details: felt252,
    );

    fn get_activity_history(
        self: @TContractState, address: ContractAddress, page: u32, limit: u32,
    ) -> Array<ActivityRecord>;

    fn validate_session(
        self: @TContractState, address: ContractAddress, session_id: felt252,
    ) -> bool;

    // Recovery
    fn initiate_recovery(
        ref self: TContractState, address: ContractAddress, recovery_method: felt252,
    ) -> felt252;

    fn complete_recovery(
        ref self: TContractState, address: ContractAddress, recovery_code: felt252,
    ) -> bool;
}

#[derive(Drop, Serde)]
struct ActivityRecord {
    timestamp: u64,
    activity_type: ActivityType,
    details: felt252,
    ip_address: felt252,
    device_info: felt252,
}

// Events
#[event]
#[derive(Drop, starknet::Event)]
enum ProfileEvent {
    ProfileCreated: ProfileCreated,
    ProfileUpdated: ProfileUpdated,
    ProfileDeleted: ProfileDeleted,
    WalletAdded: WalletAdded,
    WalletRemoved: WalletRemoved,
    SettingsUpdated: SettingsUpdated,
    VerificationCompleted: VerificationCompleted,
    ActivityRecorded: ActivityRecorded,
    RecoveryInitiated: RecoveryInitiated,
}

#[derive(Drop, starknet::Event)]
struct ProfileCreated {
    address: ContractAddress,
    username: felt252,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct ProfileUpdated {
    address: ContractAddress,
    field_updated: felt252,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct ProfileDeleted {
    address: ContractAddress,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct WalletAdded {
    owner: ContractAddress,
    wallet_address: ContractAddress,
    wallet_type: felt252,
}

#[derive(Drop, starknet::Event)]
struct WalletRemoved {
    owner: ContractAddress,
    wallet_address: ContractAddress,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct SettingsUpdated {
    address: ContractAddress,
    settings_type: felt252,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct VerificationCompleted {
    address: ContractAddress,
    status: VerificationStatus,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct ActivityRecorded {
    address: ContractAddress,
    activity_type: ActivityType,
    timestamp: u64,
}

#[derive(Drop, starknet::Event)]
struct RecoveryInitiated {
    address: ContractAddress,
    recovery_method: felt252,
    timestamp: u64,
}
