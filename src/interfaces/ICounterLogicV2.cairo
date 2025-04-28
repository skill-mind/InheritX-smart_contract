#[starknet::interface]
pub trait ICounterLogicV2<TContractState> {
    fn get_counter(self: @TContractState) -> u128;
    fn increment(ref self: TContractState);
    fn decrement(ref self: TContractState);
    fn get_version(self: @TContractState) -> felt252;
    fn increment_by(ref self: TContractState, amount: u128);
    fn reset(ref self: TContractState);
}
