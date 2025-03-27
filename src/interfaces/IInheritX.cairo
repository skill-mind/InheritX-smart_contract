use starknet::ContractAddress;
use crate::types::{SimpleBeneficiary, ActivityType, ActivityRecord, UserProfile};

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

#[derive(Copy, Drop, Serde)]
pub struct MediaMessage {
    pub plan_id: felt252,       
    pub media_type: felt252,    
    pub media_content: felt252  
}

// New Wallet struct to represent user wallets
#[derive(Drop, Serde, starknet::Store)]
pub struct Wallet {
    address: ContractAddress,
    is_primary: bool,
    wallet_type: felt252, // e.g., 'personal', 'inheritance', 'business'
    added_at: u64
}

#[starknet::interface]
pub trait IInheritX<TContractState> {
    // Initialize a new claim with a claim code
    fn create_claim(
        ref self: TContractState,
        name: felt252,
        email: felt252,
        beneficiary: ContractAddress,
        personal_message: felt252,
        amount: u256,
        claim_code: u256,
    ) -> u256;

    fn collect_claim(
        ref self: TContractState,
        inheritance_id: u256,
        beneficiary: ContractAddress,
        claim_code: u256,
    ) -> bool;

    fn record_user_activity(
        ref self: TContractState,
        user: ContractAddress,
        activity_type: ActivityType,
        details: felt252,
        ip_address: felt252,
        device_info: felt252,
    ) -> u256;

    fn get_user_activity(
        ref self: TContractState, user: ContractAddress, activity_id: u256,
    ) -> ActivityRecord;

    fn retrieve_claim(ref self: TContractState, inheritance_id: u256) -> SimpleBeneficiary;
    fn transfer_funds(ref self: TContractState, beneficiary: ContractAddress, amount: u256);
    fn test_deployment(ref self: TContractState) -> bool;

    fn get_activity_history(
        self: @TContractState, user: ContractAddress, start_index: u256, page_size: u256,
    ) -> Array<ActivityRecord>;

    fn get_activity_history_length(self: @TContractState, user: ContractAddress) -> u256;
    fn get_total_plans(self: @TContractState) -> u256;
    fn create_profile(
        ref self: TContractState,
        username: felt252,
        email: felt252,
        full_name: felt252,
        profile_image: felt252,
    ) -> bool;
    fn get_profile(ref self: TContractState, address: ContractAddress) -> UserProfile;

     // New Wallet Management Methods

    /// Add a new wallet for a user
    /// @param wallet - The wallet address to add
    /// @param wallet_type - Type of wallet (e.g., 'personal', 'inheritance')
    /// @return bool - Indicates if wallet was successfully added
    fn add_wallet(
        ref self: TContractState, 
        wallet: ContractAddress, 
        wallet_type: felt252
    ) -> bool;

    /// Set a specific wallet as the primary wallet for a user
    /// @param wallet - The wallet address to set as primary
    /// @return bool - Indicates if wallet was successfully set as primary
    fn set_primary_wallet(
        ref self: TContractState, 
        wallet: ContractAddress
    ) -> bool;

    /// Get the primary wallet for a user
    /// @param user - The user address
    /// @return ContractAddress - The primary wallet address
    fn get_primary_wallet(
        self: @TContractState, 
        user: ContractAddress
    ) -> ContractAddress;

    /// Get all wallets for a user
    /// @param user - The user address
    /// @return Array<Wallet> - Array of user's wallets
    fn get_user_wallets(
        self: @TContractState, 
        user: ContractAddress
    ) -> Array<Wallet>;

}
