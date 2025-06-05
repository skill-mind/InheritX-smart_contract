use starknet::ContractAddress;
use crate::InheritXSwap::InheritXSwap::PoolKey;

#[starknet::interface]
pub trait IInheritXSwap<TContractState> {
    // View functions
    fn get_swap_rate(
        self: @TContractState,
        token_in: ContractAddress,
        token_out: ContractAddress,
        amount_in: u256,
    ) -> u256;

    fn get_supported_tokens(self: @TContractState) -> Array<ContractAddress>;
    fn get_liquidity(
        self: @TContractState, token_a: ContractAddress, token_b: ContractAddress,
    ) -> (u256, u256);
    fn get_ordered_token_pair(
        self: @TContractState, token_a: ContractAddress, token_b: ContractAddress,
    ) -> PoolKey;

    // External functions
    fn swap_exact_tokens_for_tokens(
        ref self: TContractState,
        amount_in: u256,
        min_amount_out: u256,
        path: Array<ContractAddress>,
        recipient: ContractAddress,
        deadline: u64,
    ) -> u256;

    fn swap_tokens_for_exact_tokens(
        ref self: TContractState,
        amount_out: u256,
        max_amount_in: u256,
        path: Array<ContractAddress>,
        recipient: ContractAddress,
        deadline: u64,
    ) -> u256;

    fn add_liquidity(
        ref self: TContractState,
        token_a: ContractAddress,
        token_b: ContractAddress,
        amount_a_desired: u256,
        amount_b_desired: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        recipient: ContractAddress,
        deadline: u64,
    ) -> (u256, u256);

    fn remove_liquidity(
        ref self: TContractState,
        token_a: ContractAddress,
        token_b: ContractAddress,
        liquidity: u256,
        amount_a_min: u256,
        amount_b_min: u256,
        recipient: ContractAddress,
        deadline: u64,
    ) -> (u256, u256);

    fn add_supported_token(ref self: TContractState, token: ContractAddress);
}

#[derive(Copy, Drop, Serde)]
struct SwapRoute {
    path: Span<ContractAddress>,
    amounts: Span<u256>,
}

#[derive(Copy, Drop, Serde, Hash, starknet::Store)]
pub struct LiquidityPool {
    pub token_a: ContractAddress,
    pub token_b: ContractAddress,
    pub reserve_a: u256,
    pub reserve_b: u256,
    pub total_supply: u256,
}
