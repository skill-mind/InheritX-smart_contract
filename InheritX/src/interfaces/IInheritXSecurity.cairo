use starknet::ContractAddress;

#[starknet::interface]
trait IInheritXSecurity<TContractState> {
    // View functions
    fn is_guardian(self: @TContractState, address: ContractAddress) -> bool;
    fn is_verified(self: @TContractState, address: ContractAddress) -> bool;
    fn get_guardian_status(self: @TContractState, address: ContractAddress) -> GuardianStatus;
    fn get_verification_expiry(self: @TContractState, address: ContractAddress) -> u64;
    fn get_required_verifications(self: @TContractState, operation_type: u8) -> u8;

    // External functions
    fn register_guardian(
        ref self: TContractState,
        guardian_address: ContractAddress,
        guardian_type: u8,
        credentials: Array<felt252>,
    );

    fn verify_identity(
        ref self: TContractState,
        address: ContractAddress,
        verification_data: Array<felt252>,
        expiry_time: u64,
    );

    fn revoke_guardian(ref self: TContractState, guardian_address: ContractAddress);
    fn pause_guardian(ref self: TContractState, guardian_address: ContractAddress);
    fn resume_guardian(ref self: TContractState, guardian_address: ContractAddress);

    fn set_required_verifications(ref self: TContractState, operation_type: u8, required_count: u8);

    fn verify_operation(
        ref self: TContractState, operation_id: u256, operation_type: u8, params: Array<felt252>,
    ) -> bool;
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct GuardianStatus {
    is_active: bool,
    guardian_type: u8,
    verification_count: u32,
    last_verification: u64,
    trust_score: u8,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
struct VerificationRecord {
    verifier: ContractAddress,
    timestamp: u64,
    expiry_time: u64,
    verification_type: u8,
    data_hash: felt252,
}
