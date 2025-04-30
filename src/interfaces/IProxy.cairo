#[starknet::interface]
pub trait IProxy<TContractState> {
    fn upgrade(ref self: TContractState, new_implementation: starknet::ClassHash);
    fn get_implementation(self: @TContractState) -> starknet::ClassHash;
}
