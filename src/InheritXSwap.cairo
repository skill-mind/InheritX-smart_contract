#[starknet::contract]
pub mod InheritXSwap {
    use core::array::ArrayTrait;
    use core::num::traits::{Sqrt, Zero};
    use inheritx::interfaces::IInheritXSwap::{IInheritXSwap, LiquidityPool};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::security::ReentrancyGuardComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc20::{DefaultConfig, ERC20Component, ERC20HooksEmptyImpl};
    use starknet::storage::*;
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};

    // OpenZeppelin ERC20 component
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // OpenZeppelin Ownable component
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // OpenZeppelin ReentrancyGuard component
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent,
    );

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    impl InternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    // PoolKey struct
    #[derive(Copy, Drop, Serde, Hash, starknet::Store)]
    pub struct PoolKey {
        pub token_a: ContractAddress,
        pub token_b: ContractAddress,
    }

    // Storage
    #[storage]
    struct Storage {
        pools: Map<PoolKey, LiquidityPool>,
        shares: Map<(PoolKey, ContractAddress), u256>,
        supported_tokens: Map<ContractAddress, bool>,
        token_list: Map<u32, ContractAddress>,
        token_count: u32,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        LiquidityAdded: LiquidityAdded,
        LiquidityRemoved: LiquidityRemoved,
        TokenAdded: TokenAdded,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct LiquidityAdded {
        provider: ContractAddress,
        token_a: ContractAddress,
        token_b: ContractAddress,
        amount_a: u256,
        amount_b: u256,
        shares: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct LiquidityRemoved {
        provider: ContractAddress,
        token_a: ContractAddress,
        token_b: ContractAddress,
        amount_a: u256,
        amount_b: u256,
        shares: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct TokenAdded {
        token: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc20.initializer("InheritXSwap", "IXS");
        self.ownable.initializer(owner);
    }

    // Internal functions
    #[generate_trait]
    impl PrivateFunctions of PrivateFunctionsTrait {
        fn _mint(ref self: ContractState, pool_key: PoolKey, to: ContractAddress, amount: u256) {
            let key = (pool_key, to);
            let current_shares = self.shares.entry(key).read();
            let new_shares = current_shares + amount; // Direct addition
            self.shares.entry(key).write(new_shares);

            let mut pool = self.pools.entry(pool_key).read();
            pool.total_supply = pool.total_supply + amount; // Direct addition
            self.pools.entry(pool_key).write(pool);
        }


        fn _burn(ref self: ContractState, pool_key: PoolKey, from: ContractAddress, amount: u256) {
            let key = (pool_key, from);
            let current_shares = self.shares.entry(key).read();
            assert(current_shares >= amount, 'INSUFFICIENT_SHARES');
            let new_shares = current_shares - amount; // Direct subtraction
            self.shares.entry(key).write(new_shares);

            let mut pool = self.pools.entry(pool_key).read();
            pool.total_supply = pool.total_supply - amount; // Direct subtraction
            self.pools.entry(pool_key).write(pool);
        }

        fn _update(ref self: ContractState, pool_key: PoolKey, reserve_a: u256, reserve_b: u256) {
            let mut pool = self.pools.entry(pool_key).read();
            pool.reserve_a = reserve_a;
            pool.reserve_b = reserve_b;
            self.pools.entry(pool_key).write(pool);
        }

        fn _min(x: u256, y: u256) -> u256 {
            if x <= y {
                x
            } else {
                y
            }
        }

        fn _get_ordered_pair(token_a: ContractAddress, token_b: ContractAddress) -> PoolKey {
            if token_a < token_b {
                PoolKey { token_a, token_b }
            } else {
                PoolKey { token_a: token_b, token_b: token_a }
            }
        }

        fn _check_ratio(reserve_a: u256, reserve_b: u256, amount_a: u256, amount_b: u256) {
            if reserve_a > 0 || reserve_b > 0 {
                let left = reserve_a * amount_b; // Direct multiplication
                let right = reserve_b * amount_a; // Direct multiplication
                assert(left == right, 'INVALID_RATIO');
            }
        }
    }


    #[abi(embed_v0)]
    impl InheritXSwapImpl of IInheritXSwap<ContractState> {
        fn get_supported_tokens(self: @ContractState) -> Array<ContractAddress> {
            let mut tokens = ArrayTrait::new();
            let count = self.token_count.read();
            let mut i = 0;
            while i < count {
                let token = self.token_list.read(i);
                if token.is_non_zero() {
                    tokens.append(token);
                }
                i += 1;
            }
            tokens
        }

        fn get_liquidity(
            self: @ContractState, token_a: ContractAddress, token_b: ContractAddress,
        ) -> (u256, u256) {
            assert(token_a.is_non_zero() && token_b.is_non_zero(), 'INVALID_TOKENS');
            let pool_key = PrivateFunctions::_get_ordered_pair(token_a, token_b);
            let pool = self.pools.entry(pool_key).read();
            if token_a == pool.token_a {
                (pool.reserve_a, pool.reserve_b)
            } else {
                (pool.reserve_b, pool.reserve_a)
            }
        }

        fn add_liquidity(
            ref self: ContractState,
            token_a: ContractAddress,
            token_b: ContractAddress,
            amount_a_desired: u256,
            amount_b_desired: u256,
            amount_a_min: u256,
            amount_b_min: u256,
            recipient: ContractAddress,
            deadline: u64,
        ) -> (u256, u256) {
            self.reentrancy_guard.start();

            assert(token_a.is_non_zero() && token_b.is_non_zero(), 'INVALID_TOKENS');
            assert(recipient.is_non_zero(), 'INVALID_RECIPIENT');
            assert(amount_a_desired > 0 && amount_b_desired > 0, 'INVALID_AMOUNTS');
            assert(get_block_timestamp() <= deadline, 'DEADLINE_EXPIRED');

            let pool_key = PrivateFunctions::_get_ordered_pair(token_a, token_b);
            let is_ordered = token_a == pool_key.token_a;
            let (amount_a, amount_b) = if is_ordered {
                (amount_a_desired, amount_b_desired)
            } else {
                (amount_b_desired, amount_a_desired)
            };

            let (min_a, min_b) = if is_ordered {
                (amount_a_min, amount_b_min)
            } else {
                (amount_b_min, amount_a_min)
            };

            // Create ERC20 dispatchers
            let (token0, token1): (IERC20Dispatcher, IERC20Dispatcher) = (
                IERC20Dispatcher { contract_address: pool_key.token_a },
                IERC20Dispatcher { contract_address: pool_key.token_b },
            );

            let mut pool = self.pools.entry(pool_key).read();
            let total_supply = pool.total_supply;

            // Calculate liquidity shares to mint per pool/user
            let shares: u256 = if total_supply.is_zero() {
                // Initialize pool
                // Consider minting a _MINIMUM_LIQUIDITY of 10e3 tokens
                // locked at the zero address (0) to ensure the pool has a non-zero total supply

                let mut new_pool = LiquidityPool {
                    token_a: pool_key.token_a,
                    token_b: pool_key.token_b,
                    reserve_a: 0,
                    reserve_b: 0,
                    total_supply: 0,
                };
                self.pools.write(pool_key, new_pool);

                // Register tokens
                if !self.supported_tokens.entry(pool_key.token_a).read() {
                    let count = self.token_count.read();
                    self.supported_tokens.entry(pool_key.token_a).write(true);
                    self.token_list.entry(count).write(pool_key.token_a);
                    self.token_count.write(count + 1);
                }
                if !self.supported_tokens.entry(pool_key.token_b).read() {
                    let count = self.token_count.read();
                    self.supported_tokens.entry(pool_key.token_b).write(true);
                    self.token_list.entry(count).write(pool_key.token_b);
                    self.token_count.write(count + 1);
                }
                // Shares = sqrt(amount_a * amount_b)
                (amount_a * amount_b).sqrt().into()
            } else {
                PrivateFunctions::_check_ratio(pool.reserve_a, pool.reserve_b, amount_a, amount_b);
                let shares_a = amount_a * pool.total_supply / pool.reserve_a;
                let shares_b = amount_b * pool.total_supply / pool.reserve_b;
                PrivateFunctions::_min(shares_a, shares_b)
            };

            assert(shares > 0, 'INSUFFICIENT_SHARES_MINTED');
            assert(amount_a >= min_a && amount_b >= min_b, 'INSUFFICIENT_AMOUNT');

            // Transfer tokens
            token0.transfer_from(get_caller_address(), get_contract_address(), amount_a);
            token1.transfer_from(get_caller_address(), get_contract_address(), amount_b);

            // Update reserves
            let new_reserve_a = pool.reserve_a + amount_a; // Direct addition
            let new_reserve_b = pool.reserve_b + amount_b; // Direct addition
            PrivateFunctions::_update(ref self, pool_key, new_reserve_a, new_reserve_b);
            PrivateFunctions::_mint(ref self, pool_key, recipient, shares);

            // Emit event
            self
                .emit(
                    LiquidityAdded {
                        provider: get_caller_address(),
                        token_a: pool_key.token_a,
                        token_b: pool_key.token_b,
                        amount_a,
                        amount_b,
                        shares,
                    },
                );

            self.reentrancy_guard.end();

            if is_ordered {
                (amount_a, amount_b)
            } else {
                (amount_b, amount_a)
            }
        }

        fn remove_liquidity(
            ref self: ContractState,
            token_a: ContractAddress,
            token_b: ContractAddress,
            liquidity: u256,
            amount_a_min: u256,
            amount_b_min: u256,
            recipient: ContractAddress,
            deadline: u64,
        ) -> (u256, u256) {
            self.reentrancy_guard.start();

            // Validate inputs
            assert(token_a.is_non_zero() && token_b.is_non_zero(), 'INVALID_TOKENS');
            assert(recipient.is_non_zero(), 'INVALID_RECIPIENT');
            assert(liquidity > 0, 'INVALID_LIQUIDITY');
            assert(get_block_timestamp() <= deadline, 'DEADLINE_EXPIRED');

            let pool_key = PrivateFunctions::_get_ordered_pair(token_a, token_b);
            let is_ordered = token_a == pool_key.token_a;
            let (min_a, min_b) = if is_ordered {
                (amount_a_min, amount_b_min)
            } else {
                (amount_b_min, amount_a_min)
            };

            // Create ERC20 dispatchers
            let (token0, token1): (IERC20Dispatcher, IERC20Dispatcher) = (
                IERC20Dispatcher { contract_address: pool_key.token_a },
                IERC20Dispatcher { contract_address: pool_key.token_b },
            );

            let pool = self.pools.entry(pool_key).read();
            assert(pool.total_supply > 0, 'POOL_NOT_FOUND');

            let key = (pool_key, get_caller_address());
            let user_shares = self.shares.entry(key).read();
            assert(user_shares >= liquidity, 'INSUFFICIENT_SHARES');

            // Calculate amounts to withdraw
            let amount_a = liquidity * pool.reserve_a; // Direct multiplication
            let amount_a_final = amount_a / pool.total_supply;
            let amount_b = liquidity * pool.reserve_b; // Direct multiplication
            let amount_b_final = amount_b / pool.total_supply;

            assert(amount_a_final >= min_a && amount_b_final >= min_b, 'INSUFFICIENT_AMOUNT');
            assert(amount_a_final > 0 && amount_b_final > 0, 'INSUFFICIENT_LIQUIDITY_BURNED');

            // Update pool state
            let new_reserve_a = pool.reserve_a - amount_a_final; // Direct subtraction
            let new_reserve_b = pool.reserve_b - amount_b_final; // Direct subtraction

            PrivateFunctions::_burn(ref self, pool_key, get_caller_address(), liquidity);
            PrivateFunctions::_update(ref self, pool_key, new_reserve_a, new_reserve_b);

            // Transfer tokens to recipient
            token0.transfer(recipient, amount_a_final);
            token1.transfer(recipient, amount_b_final);

            // Emit event
            self
                .emit(
                    LiquidityRemoved {
                        provider: get_caller_address(),
                        token_a: pool_key.token_a,
                        token_b: pool_key.token_b,
                        amount_a: amount_a_final,
                        amount_b: amount_b_final,
                        shares: liquidity,
                    },
                );

            self.reentrancy_guard.end();

            if is_ordered {
                (amount_a_final, amount_b_final)
            } else {
                (amount_b_final, amount_a_final)
            }
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn add_supported_token(ref self: ContractState, token: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(token.is_non_zero(), 'INVALID_TOKEN');
            assert(!self.supported_tokens.entry(token).read(), 'TOKEN_ALREADY_SUPPORTED');

            let count = self.token_count.read();
            self.token_list.entry(count).write(token);
            self.token_count.write(count + 1);
            self.supported_tokens.entry(token).write(true);
            self.emit(TokenAdded { token });
        }
    }
}
