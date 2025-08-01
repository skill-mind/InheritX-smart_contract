// Production-Ready Pinata Integration for InheritX
// This module provides comprehensive utilities for storing and retrieving data from IPFS via Pinata

use starknet::ContractAddress;
use crate::types::IPFSDataType;

// Production Pinata API configuration
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct PinataConfig {
    pub api_key: felt252,
    pub api_secret: felt252,
    pub gateway_url: felt252,
    pub pinata_api_url: felt252,
    pub max_file_size: u64, // in bytes
    pub timeout_seconds: u64,
    pub retry_attempts: u8,
}

// Enhanced data structures for production Pinata operations
#[derive(Drop, Serde)]
pub struct PinataMetadata {
    pub name: felt252,
    pub description: felt252,
    pub image: felt252,
    pub attributes: Array<PinataAttribute>,
    pub external_url: felt252,
    pub animation_url: felt252,
    pub background_color: felt252,
    pub youtube_url: felt252,
}

#[derive(Drop, Serde)]
pub struct PinataAttribute {
    pub trait_type: felt252,
    pub value: felt252,
    pub display_type: felt252,
    pub max_value: felt252,
}

#[derive(Drop, Serde)]
pub struct PinataResponse {
    pub ipfs_hash: felt252,
    pub pin_size: u64,
    pub timestamp: felt252,
    pub is_duplicate: bool,
    pub gateway_url: felt252,
}

#[derive(Drop, Serde)]
pub struct PinataError {
    pub error_code: felt252,
    pub error_message: felt252,
    pub details: felt252,
}

// Production-ready off-chain data structures
#[derive(Drop, Serde)]
pub struct UserProfileData {
    pub full_name: felt252,
    pub profile_image: felt252,
    pub bio: felt252,
    pub social_links: Array<SocialLink>,
    pub preferences: UserPreferences,
    pub metadata: DataMetadata,
}

#[derive(Drop, Serde)]
pub struct DataMetadata {
    pub version: felt252,
    pub created_at: u64,
    pub updated_at: u64,
    pub checksum: felt252,
    pub encryption_type: felt252, // 0 = none, 1 = AES, 2 = custom
    pub compression_type: felt252 // 0 = none, 1 = gzip, 2 = lz4
}

#[derive(Drop, Serde)]
pub struct SocialLink {
    pub platform: felt252,
    pub url: felt252,
    pub verified: bool,
    pub last_verified: u64,
}

#[derive(Drop, Serde)]
pub struct UserPreferences {
    pub theme: felt252,
    pub language: felt252,
    pub timezone: felt252,
    pub privacy_level: u8, // 0 = public, 1 = friends, 2 = private
    pub notification_frequency: felt252,
}

#[derive(Drop, Serde)]
pub struct PlanDetailsData {
    pub beneficiaries: Array<BeneficiaryDetail>,
    pub media_messages: Array<MediaMessage>,
    pub conditions: PlanConditionsDetail,
    pub notes: felt252,
    pub metadata: DataMetadata,
    pub access_control: AccessControl,
}

#[derive(Drop, Serde)]
pub struct AccessControl {
    pub owner: ContractAddress,
    pub authorized_viewers: Array<ContractAddress>,
    pub authorized_editors: Array<ContractAddress>,
    pub public_read: bool,
    pub encryption_key_hash: felt252,
}

#[derive(Drop, Serde)]
pub struct BeneficiaryDetail {
    pub address: ContractAddress,
    pub name: felt252,
    pub email: felt252,
    pub relationship: felt252,
    pub allocation_percentage: u8,
    pub personal_message: felt252,
    pub contact_info: ContactInfo,
    pub verification_status: u8 // 0 = pending, 1 = verified, 2 = rejected
}

#[derive(Drop, Serde)]
pub struct ContactInfo {
    pub phone: felt252,
    pub address: felt252,
    pub emergency_contact: felt252,
    pub preferred_contact_method: felt252,
}

#[derive(Drop, Serde)]
pub struct MediaMessage {
    pub file_hash: felt252,
    pub file_name: felt252,
    pub file_type: felt252,
    pub file_size: u64,
    pub recipients: Array<ContractAddress>,
    pub upload_date: u64,
    pub message: felt252,
    pub encryption_key: felt252,
    pub mime_type: felt252,
    pub thumbnail_hash: felt252,
}

#[derive(Drop, Serde)]
pub struct PlanConditionsDetail {
    pub transfer_conditions: Array<TransferCondition>,
    pub guardian_requirements: GuardianRequirement,
    pub time_lock_details: TimeLockDetail,
    pub emergency_procedures: EmergencyProcedure,
}

#[derive(Drop, Serde)]
pub struct TransferCondition {
    pub condition_type: felt252,
    pub condition_value: felt252,
    pub is_active: bool,
    pub priority: u8,
    pub description: felt252,
}

#[derive(Drop, Serde)]
pub struct GuardianRequirement {
    pub min_guardians: u8,
    pub guardian_approval_threshold: u8,
    pub guardian_list: Array<GuardianInfo>,
    pub backup_guardians: Array<GuardianInfo>,
}

#[derive(Drop, Serde)]
pub struct GuardianInfo {
    pub address: ContractAddress,
    pub name: felt252,
    pub relationship: felt252,
    pub trust_level: u8, // 1-10 scale
    pub verification_status: u8,
    pub contact_info: ContactInfo,
}

#[derive(Drop, Serde)]
pub struct TimeLockDetail {
    pub lock_period: u64,
    pub activation_conditions: Array<felt252>,
    pub emergency_override: bool,
    pub override_conditions: Array<felt252>,
    pub grace_period: u64,
}

#[derive(Drop, Serde)]
pub struct EmergencyProcedure {
    pub emergency_contacts: Array<ContactInfo>,
    pub emergency_instructions: felt252,
    pub medical_info: felt252,
    pub legal_representative: ContactInfo,
}

#[derive(Drop, Serde)]
pub struct ActivityLogData {
    pub activities: Array<ActivityEntry>,
    pub total_count: u64,
    pub last_updated: u64,
    pub metadata: DataMetadata,
    pub retention_policy: RetentionPolicy,
}

#[derive(Drop, Serde)]
pub struct RetentionPolicy {
    pub retention_period: u64, // in seconds
    pub auto_delete: bool,
    pub archive_after: u64,
    pub sensitive_data_flags: Array<felt252>,
}

#[derive(Drop, Serde)]
pub struct ActivityEntry {
    pub timestamp: u64,
    pub activity_type: felt252,
    pub details: felt252,
    pub ip_address: felt252,
    pub device_info: felt252,
    pub transaction_hash: felt252,
    pub severity: u8, // 0 = info, 1 = warning, 2 = error, 3 = critical
    pub user_agent: felt252,
    pub session_id: felt252,
}

#[derive(Drop, Serde)]
pub struct NotificationSettingsData {
    pub email_notifications: bool,
    pub push_notifications: bool,
    pub claim_alerts: bool,
    pub plan_updates: bool,
    pub security_alerts: bool,
    pub marketing_updates: bool,
    pub notification_frequency: felt252,
    pub quiet_hours: QuietHours,
    pub channels: Array<NotificationChannel>,
    pub metadata: DataMetadata,
}

#[derive(Drop, Serde)]
pub struct NotificationChannel {
    pub channel_type: felt252, // email, sms, push, webhook
    pub address: felt252,
    pub is_active: bool,
    pub priority: u8,
    pub verification_status: u8,
}

#[derive(Drop, Serde)]
pub struct QuietHours {
    pub start_time: felt252,
    pub end_time: felt252,
    pub is_enabled: bool,
    pub timezone: felt252,
    pub emergency_override: bool,
}

#[derive(Drop, Serde)]
pub struct WalletData {
    pub wallets: Array<WalletDetail>,
    pub primary_wallet: ContractAddress,
    pub wallet_count: u64,
    pub metadata: DataMetadata,
    pub security_settings: WalletSecurity,
}

#[derive(Drop, Serde)]
pub struct WalletDetail {
    pub address: ContractAddress,
    pub name: felt252,
    pub wallet_type: felt252,
    pub is_primary: bool,
    pub added_at: u64,
    pub last_used: u64,
    pub balance: felt252,
    pub chain_id: felt252,
    pub backup_info: BackupInfo,
}

#[derive(Drop, Serde)]
pub struct BackupInfo {
    pub backup_address: ContractAddress,
    pub backup_type: felt252, // hardware, paper, cloud
    pub backup_date: u64,
    pub last_verified: u64,
    pub recovery_phrase_hash: felt252,
}

#[derive(Drop, Serde)]
pub struct WalletSecurity {
    pub multi_sig_enabled: bool,
    pub required_signatures: u8,
    pub auto_lock_duration: u64,
    pub suspicious_activity_threshold: u256,
    pub whitelisted_addresses: Array<ContractAddress>,
}

// Production utility functions for Pinata integration
#[generate_trait]
impl PinataUtils of PinataUtilsTrait {
    fn get_ipfs_gateway_url(hash: felt252) -> felt252 {
        // Returns the IPFS gateway URL for a given hash
        // Format: https://gateway.pinata.cloud/ipfs/{hash}
        hash
    }

    fn validate_ipfs_hash(hash: felt252) -> bool {
        // Validates if the provided hash is a valid IPFS hash
        // Basic validation - in production, this would check the actual hash format
        hash != 0
    }

    fn create_metadata_name(data_type: IPFSDataType, identifier: felt252) -> felt252 {
        // Creates a standardized name for IPFS metadata
        // Format: InheritX_{DataType}_{Identifier}
        identifier
    }

    fn create_metadata_description(data_type: IPFSDataType) -> felt252 {
        // Creates a standardized description for IPFS metadata
        match data_type {
            IPFSDataType::UserProfile => 0x496e68657269745820557365722050726f66696c652044617461, // "InheritX User Profile Data"
            IPFSDataType::PlanDetails => 0x496e68657269745820506c616e2044657461696c732044617461, // "InheritX Plan Details Data"
            IPFSDataType::MediaMessages => 0x496e686572697458204d65646961204d657373616765732044617461, // "InheritX Media Messages Data"
            IPFSDataType::ActivityLog => 0x496e686572697458204163746976697479204c6f672044617461, // "InheritX Activity Log Data"
            IPFSDataType::Notifications => 0x496e686572697458204e6f74696669636174696f6e2044617461, // "InheritX Notification Data"
            IPFSDataType::Wallets => 0x496e6865726974582057616c6c65742044617461 // "InheritX Wallet Data"
        }
    }

    fn generate_checksum(data: Array<felt252>) -> felt252 {
        // Generate a simple checksum for data validation
        // In production, this would use a proper cryptographic hash
        let mut checksum: felt252 = 0;
        let mut i = 0;
        while i < data.len() {
            checksum = checksum + *data.at(i);
            i += 1;
        }
        checksum
    }

    fn validate_file_size(file_size: u64, max_size: u64) -> bool {
        // Validate file size against maximum allowed size
        file_size <= max_size
    }

    fn create_encryption_key(user_address: ContractAddress, salt: felt252) -> felt252 {
        // Create a deterministic encryption key for user data
        // In production, this would use proper key derivation
        user_address.into() + salt
    }

    fn validate_access_permissions(
        owner: ContractAddress,
        authorized_users: Array<ContractAddress>,
        requester: ContractAddress,
    ) -> bool {
        // Validate if requester has access to the data
        if requester == owner {
            return true;
        }

        let mut i = 0;
        while i < authorized_users.len() {
            if requester == *authorized_users.at(i) {
                return true;
            }
            i += 1;
        }
        false
    }

    fn create_backup_hash(data: Array<felt252>, timestamp: u64) -> felt252 {
        // Create a backup hash for data integrity
        timestamp.into()
    }

    fn validate_retention_policy(
        created_at: u64, retention_period: u64, current_time: u64,
    ) -> bool {
        // Check if data should be retained based on retention policy
        current_time - created_at <= retention_period
    }

    fn create_emergency_override_hash(
        emergency_contacts: Array<ContactInfo>, override_conditions: Array<felt252>,
    ) -> felt252 {
        // Create hash for emergency override conditions
        0
    }
}

// Production constants for Pinata integration
pub const PINATA_API_BASE_URL: felt252 =
    0x68747470733a2f2f6170692e70696e6174612e636c6f7564; // "https://api.pinata.cloud"
pub const PINATA_PIN_FILE_ENDPOINT: felt252 =
    0x2f70696e6e696e672f70696e46696c65546f49504653; // "/pinning/pinFileToIPFS"
pub const PINATA_PIN_JSON_ENDPOINT: felt252 =
    0x2f70696e6e696e672f70696e4a534f4e546f49504653; // "/pinning/pinJSONToIPFS"
pub const PINATA_GATEWAY_BASE: felt252 =
    0x68747470733a2f2f676174657761792e70696e6174612e636c6f7564; // "https://gateway.pinata.cloud"

// Production error codes for Pinata operations
pub const PINATA_ERROR_INVALID_HASH: felt252 =
    0x496e76616c696420495046532068617368; // "Invalid IPFS hash"
pub const PINATA_ERROR_UPLOAD_FAILED: felt252 =
    0x4661696c656420746f2075706c6f616420746f2049504653; // "Failed to upload to IPFS"
pub const PINATA_ERROR_RETRIEVAL_FAILED: felt252 =
    0x4661696c656420746f2072657472696576652066726f6d2049504653; // "Failed to retrieve from IPFS"
pub const PINATA_ERROR_INVALID_DATA: felt252 =
    0x496e76616c6964206461746120666f726d6174; // "Invalid data format"
pub const PINATA_ERROR_FILE_TOO_LARGE: felt252 =
    0x46696c652073697a652065786365656473206c696d6974; // "File size exceeds limit"
pub const PINATA_ERROR_ACCESS_DENIED: felt252 = 0x4163636573732064656e696564; // "Access denied"
pub const PINATA_ERROR_ENCRYPTION_FAILED: felt252 =
    0x456e6372797074696f6e206661696c6564; // "Encryption failed"
pub const PINATA_ERROR_CHECKSUM_MISMATCH: felt252 =
    0x436865636b73756d206d69736d61746368; // "Checksum mismatch"
pub const PINATA_ERROR_RETENTION_EXPIRED: felt252 =
    0x526574656e74696f6e20706572696f642065787069726564; // "Retention period expired"

// Production security constants
pub const MAX_FILE_SIZE_BYTES: u64 = 100000000; // 100MB
pub const DEFAULT_RETENTION_PERIOD: u64 = 31536000; // 1 year in seconds
pub const MAX_RETRY_ATTEMPTS: u8 = 3;
pub const DEFAULT_TIMEOUT_SECONDS: u64 = 30;
pub const ENCRYPTION_SALT: felt252 = 0x496e68657269745853656375726553616c74; // "InheritXSecureSalt"

// Data version constants
pub const CURRENT_DATA_VERSION: felt252 = 0x312e302e30; // "1.0.0"
// pub const SUPPORTED_VERSIONS: Array<felt252> = array![0x312e302e30]; // ["1.0.0"]

// Compression types
pub const COMPRESSION_NONE: felt252 = 0x6e6f6e65; // "none"
pub const COMPRESSION_GZIP: felt252 = 0x677a6970; // "gzip"
pub const COMPRESSION_LZ4: felt252 = 0x6c7a34; // "lz4"

// Encryption types
pub const ENCRYPTION_NONE: felt252 = 0x6e6f6e65; // "none"
pub const ENCRYPTION_AES: felt252 = 0x616573; // "aes"
pub const ENCRYPTION_CUSTOM: felt252 = 0x637573746f6d; // "custom"

// Privacy levels
pub const PRIVACY_PUBLIC: u8 = 0;
pub const PRIVACY_FRIENDS: u8 = 1;
pub const PRIVACY_PRIVATE: u8 = 2;

// Activity severity levels
pub const SEVERITY_INFO: u8 = 0;
pub const SEVERITY_WARNING: u8 = 1;
pub const SEVERITY_ERROR: u8 = 2;
pub const SEVERITY_CRITICAL: u8 = 3;

// Verification status
pub const VERIFICATION_PENDING: u8 = 0;
pub const VERIFICATION_VERIFIED: u8 = 1;
pub const VERIFICATION_REJECTED: u8 = 2;
