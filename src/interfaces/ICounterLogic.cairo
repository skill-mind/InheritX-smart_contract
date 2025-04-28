#[starknet::interface]
pub trait ICounterLogic<TContractState> {
    fn get_counter(self: @TContractState) -> u128;
    fn increment(ref self: TContractState);
    fn decrement(ref self: TContractState);
    fn get_version(self: @TContractState) -> felt252;
}

