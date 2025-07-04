#[starknet::interface]
pub trait IGuardianAccount<TContractState> {
    fn approve_claim(ref self: TContractState, claim_id: felt252) -> bool;
    fn is_signer(self: @TContractState, signer: felt252) -> bool;
    fn get_required_signatures(self: @TContractState) -> u8;
    fn get_current_signatures(self: @TContractState, claim_id: felt252) -> u8;
    fn add_signer(ref self: TContractState, signer: felt252) -> bool;
    fn remove_signer(ref self: TContractState, signer: felt252) -> bool;
    fn get_signers(self: @TContractState) -> Array<felt252>;
    fn revoke_approval(ref self: TContractState, claim_id: felt252) -> bool;
}
