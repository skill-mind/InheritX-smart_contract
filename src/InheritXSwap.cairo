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
        // Mapping of token pairs to their liquidity pools
        pools: Map<PoolKey, LiquidityPool>,
        // Mapping of user's liquidity positions
        shares: Map<(PoolKey, ContractAddress), u256>,
        // Mapping of supported tokens to their status
        // true if the token is supported, false otherwise
        supported_tokens: Map<ContractAddress, bool>,
        // List of supported tokens
        token_list: Map<u32, ContractAddress>,
        // Count of supported tokens
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
    #[derive(Drop, Destruct, starknet::Event)]
    pub enum Event {
        LiquidityAdded: LiquidityAdded,
        LiquidityRemoved: LiquidityRemoved,
        TokenAdded: TokenAdded,
        Swap: Swap,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
    }

    #[derive(Drop, Clone, starknet::Event)]
    pub struct Swap {
        pub sender: ContractAddress,
        pub token_in: ContractAddress,
        pub token_out: ContractAddress,
        pub amount_in: u256,
        pub amount_out: u256,
        pub recipient: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LiquidityAdded {
        pub provider: ContractAddress,
        pub token_a: ContractAddress,
        pub token_b: ContractAddress,
        pub amount_a: u256,
        pub amount_b: u256,
        pub liquidity: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct LiquidityRemoved {
        pub recipient: ContractAddress,
        pub token_a: ContractAddress,
        pub token_b: ContractAddress,
        pub amount_a: u256,
        pub amount_b: u256,
        pub liquidity: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct TokenAdded {
        token: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        let name: ByteArray = "InheritXSwap";
        let symbol: ByteArray = "IXS";

        self.erc20.initializer(name, symbol);
        self.ownable.initializer(owner);
    }

    // Internal functions
    #[generate_trait]
    impl PrivateFunctions of PrivateFunctionsTrait {
        fn _mint(ref self: ContractState, pool_key: PoolKey, to: ContractAddress, amount: u256) {
            // update LP shares/tokens balance per user
            let key = (pool_key, to);
            let current_shares = self.shares.entry(key).read();
            let new_shares = current_shares + amount; // Direct addition
            self.shares.entry(key).write(new_shares);

            // update LP total supply
            let mut pool = self.pools.entry(pool_key).read();
            pool.total_supply = pool.total_supply + amount; // Direct addition
            self.pools.entry(pool_key).write(pool);
            // // mints LP tokens (ERC20) to represent user's liquidity share
        // self.erc20.mint(to, amount);
        }


        fn _burn(ref self: ContractState, pool_key: PoolKey, from: ContractAddress, amount: u256) {
            // update LP shares/tokens balance per user
            let key = (pool_key, from);
            let current_shares = self.shares.entry(key).read();
            assert(current_shares >= amount, 'INSUFFICIENT_LIQUIDITY');
            let new_shares = current_shares - amount; // Direct subtraction
            self.shares.entry(key).write(new_shares);

            // update LP total supply
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
        // Get supported tokens
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

        // Get liquidity reserves for a token pair
        fn get_liquidity(
            self: @ContractState, token_a: ContractAddress, token_b: ContractAddress,
        ) -> (u256, u256) {
            let pool_key = self.get_ordered_token_pair(token_a, token_b);
            let pool = self.pools.entry(pool_key).read();
            if token_a == pool.token_a {
                (pool.reserve_a, pool.reserve_b)
            } else {
                (pool.reserve_b, pool.reserve_a)
            }
        }

        // Get ordered token pair for a given token pair
        fn get_ordered_token_pair(
            self: @ContractState, token_a: ContractAddress, token_b: ContractAddress,
        ) -> PoolKey {
            assert(token_a.is_non_zero() && token_b.is_non_zero(), 'INVALID_TOKENS');
            assert(token_a != token_b, 'IDENTICAL_TOKENS');
            // Ensure both tokens are supported
            assert(
                self.supported_tokens.entry(token_a).read()
                    && self.supported_tokens.entry(token_b).read(),
                'TOKENS_NOT_SUPPORTED',
            );
            PrivateFunctions::_get_ordered_pair(token_a, token_b)
        }

        // Add liquidity to a pool
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

            // Validate inputs
            assert(token_a.is_non_zero() && token_b.is_non_zero(), 'INVALID_TOKENS');
            assert(token_a != token_b, 'IDENTICAL_TOKENS');
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
            let (caller, contract) = (get_caller_address(), get_contract_address());

            let pool = self.pools.entry(pool_key).read();
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
                // LP Shares = sqrt(amount_a * amount_b)
                (amount_a * amount_b).sqrt().into()
            } else {
                PrivateFunctions::_check_ratio(pool.reserve_a, pool.reserve_b, amount_a, amount_b);
                let shares_a = amount_a * pool.total_supply / pool.reserve_a;
                let shares_b = amount_b * pool.total_supply / pool.reserve_b;
                PrivateFunctions::_min(shares_a, shares_b)
            };

            // Verify minimum amounts
            assert(shares > 0, 'INSUFFICIENT_LIQUIDITY_MINTED');
            assert(amount_a >= min_a && amount_b >= min_b, 'INSUFFICIENT_AMOUNT_TO_MINIMUM');

            // Check balances
            assert(
                token0.balance_of(caller) >= amount_a && token1.balance_of(caller) >= amount_b,
                'INSUFFICIENT_CALLER_BALANCE',
            );

            // Transfer tokens to contract
            token0.transfer_from(caller, contract, amount_a);
            token1.transfer_from(caller, contract, amount_b);

            // Update reserves
            let new_reserve_a = pool.reserve_a + amount_a; // Direct addition
            let new_reserve_b = pool.reserve_b + amount_b; // Direct addition
            PrivateFunctions::_update(ref self, pool_key, new_reserve_a, new_reserve_b);
            PrivateFunctions::_mint(ref self, pool_key, recipient, shares);

            // Emit event
            self
                .emit(
                    LiquidityAdded {
                        provider: caller,
                        token_a: pool_key.token_a,
                        token_b: pool_key.token_b,
                        amount_a,
                        amount_b,
                        liquidity: shares,
                    },
                );

            self.reentrancy_guard.end();

            // Return amounts of liquidity added, in the order of the pool key
            if is_ordered {
                (amount_a, amount_b)
            } else {
                (amount_b, amount_a)
            }
        }

        // Remove liquidity from a pool
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
            assert(token_a != token_b, 'IDENTICAL_TOKENS');
            assert(recipient.is_non_zero(), 'INVALID_RECIPIENT');
            assert(liquidity > 0, 'INVALID_LIQUIDITY_ENTRY');
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
            // Get caller and contract addresses
            let (caller, contract) = (get_caller_address(), get_contract_address());

            let pool = self.pools.entry(pool_key).read();

            // Conduct pool checks
            assert(pool.total_supply > 0, 'POOL_NOT_FOUND');
            assert(pool.reserve_a > 0 && pool.reserve_b > 0, 'EMPTY_POOL');

            let key = (pool_key, recipient);
            let user_shares = self.shares.entry(key).read();
            assert(user_shares >= liquidity, 'INSUFFICIENT_USER_LIQUIDITY');

            // Calculate share of pool to withdraw
            let amount_a = liquidity * pool.reserve_a / pool.total_supply; // Direct multiplication
            let amount_b = liquidity * pool.reserve_b / pool.total_supply; // Direct multiplication

            // Ensure amounts are sufficient
            assert(amount_a >= min_a, 'INSUFFICIENT_AMOUNT_A');
            assert(amount_b >= min_b, 'INSUFFICIENT_AMOUNT_B');
            assert(amount_a > 0 && amount_b > 0, 'INSUFFICIENT_LIQUIDITY_BURN');

            // Update pool state before transfers
            let new_reserve_a = pool.reserve_a - amount_a; // Direct subtraction
            let new_reserve_b = pool.reserve_b - amount_b; // Direct subtraction

            PrivateFunctions::_burn(ref self, pool_key, recipient, liquidity);
            PrivateFunctions::_update(ref self, pool_key, new_reserve_a, new_reserve_b);

            // Check contract balances
            assert(token0.balance_of(contract) >= amount_a, 'INSUFFICIENT_TOKEN0_BALANCE');
            assert(token1.balance_of(contract) >= amount_b, 'INSUFFICIENT_TOKEN1_BALANCE');

            // Transfer tokens to recipient
            token0.transfer(recipient, amount_a);
            token1.transfer(recipient, amount_b);

            // Emit event
            self
                .emit(
                    LiquidityRemoved {
                        recipient: recipient,
                        token_a: pool_key.token_a,
                        token_b: pool_key.token_b,
                        amount_a,
                        amount_b,
                        liquidity,
                    },
                );

            self.reentrancy_guard.end();

            // Return amounts of liquidity removed, in the order of the pool key
            if is_ordered {
                (amount_a, amount_b)
            } else {
                (amount_b, amount_a)
            }
        }

        fn get_swap_rate(
            self: @ContractState,
            token_in: ContractAddress,
            token_out: ContractAddress,
            amount_in: u256,
        ) -> u256 {
            // Input validation
            assert(token_in.is_non_zero() && token_out.is_non_zero(), 'INVALID_TOKENS');
            assert(token_in != token_out, 'IDENTICAL_TOKENS');
            assert(amount_in > 0, 'INVALID_AMOUNT_IN');

            // Ensure both tokens are supported
            assert(
                self.supported_tokens.entry(token_in).read()
                    && self.supported_tokens.entry(token_out).read(),
                'TOKENS_NOT_SUPPORTED',
            );

            // Get the ordered token pair to access the pool
            let pool_key = PrivateFunctions::_get_ordered_pair(token_in, token_out);
            let pool = self.pools.entry(pool_key).read();

            // Validate pool exists and has liquidity
            assert(pool.total_supply > 0, 'POOL_NOT_FOUND');
            assert(pool.reserve_a > 0 && pool.reserve_b > 0, 'INSUFFICIENT_LIQUIDITY');

            // Determine which reserve corresponds to input/output tokens
            let (reserve_in, reserve_out) = if token_in == pool_key.token_a {
                (pool.reserve_a, pool.reserve_b)
            } else {
                (pool.reserve_b, pool.reserve_a)
            };

            // Calculate swap rate using constant product formula: (x * y = k)
            // For swap: amount_out = (amount_in * reserve_out) / (reserve_in + amount_in)
            let numerator = amount_in * reserve_out;
            let denominator = reserve_in + amount_in;

            // Ensure we don't divide by zero (should be prevented by liquidity checks above)
            assert(denominator > 0, 'CALCULATION_ERROR');

            let amount_out = numerator / denominator;

            // Ensure the swap would result in a non-zero output
            assert(amount_out > 0, 'INSUFFICIENT_OUTPUT_AMOUNT');

            // Additional check: ensure we don't drain the output reserve
            assert(amount_out < reserve_out, 'EXCESSIVE_INPUT_AMOUNT');

            amount_out
        }

        fn swap_exact_tokens_for_tokens(
            ref self: ContractState,
            amount_in: u256,
            min_amount_out: u256,
            path: Array<ContractAddress>,
            recipient: ContractAddress,
            deadline: u64,
        ) -> u256 {
            // Implementation will be added in a separate PR
            0
        }

        fn swap_tokens_for_exact_tokens(
            ref self: ContractState,
            amount_out: u256,
            max_amount_in: u256,
            path: Array<ContractAddress>,
            recipient: ContractAddress,
            deadline: u64,
        ) -> u256 {
            self.reentrancy_guard.start();

            // Input validation with descriptive error messages
            assert(amount_out > 0, 'Invalid amount: must be > 0');
            assert(max_amount_in > 0, 'Invalid max input: must be > 0');
            assert(recipient.is_non_zero(), 'Invalid recipient: zero address');
            assert(get_block_timestamp() <= deadline, 'Deadline exceeded');
            assert(path.len() >= 2, 'Invalid path: need min 2 tokens');

            // Validate all addresses in path are non-zero and supported
            let mut i = 0;
            while i != path.len() {
                let token = path.at(i);
                assert(token.is_non_zero(), 'Invalid path: zero address');
                assert(self.supported_tokens.read(*token), 'Unsupported token in path');
                i += 1;
            }

            // Only support single-hop swaps (path.len() == 2)
            assert(path.len() == 2, 'Multi-hop not implemented');

            let token_in = path.at(0);
            let token_out = path.at(1);

            // Get pool key and reserves
            let pool_key = PrivateFunctions::_get_ordered_pair(*token_in, *token_out);
            let pool = self.pools.read(pool_key);
            assert(pool.total_supply > 0, 'Pool not found');
            assert(pool.reserve_a > 0 && pool.reserve_b > 0, 'Empty pool');

            // Determine which token is input and which is output
            let (reserve_in, reserve_out) = if *token_in == pool.token_a {
                (pool.reserve_a, pool.reserve_b)
            } else {
                (pool.reserve_b, pool.reserve_a)
            };

            // Calculate required input using constant product formula with 0.3% fee
            // Formula: amount_in = (reserve_in * amount_out * 1000) / ((reserve_out - amount_out) *
            // 997) + 1
            assert(reserve_out > amount_out, 'Insufficient output liquidity');
            let numerator = reserve_in * amount_out * 1000_u256;
            let denominator = (reserve_out - amount_out) * 997_u256;
            let mut amount_in = numerator / denominator + 1_u256;

            // Ensure the calculated input amount doesn't exceed the user's maximum
            assert(amount_in <= max_amount_in, 'Excessive input amount');

            // Get caller and contract addresses
            let caller = get_caller_address();
            let contract = get_contract_address();

            // Create token dispatchers for interacting with the ERC20 tokens
            let input_token = IERC20Dispatcher { contract_address: *token_in };
            let output_token = IERC20Dispatcher { contract_address: *token_out };

            // Verify caller has sufficient balance and allowance
            assert(input_token.balance_of(caller) >= amount_in, 'Insufficient balance');
            assert(input_token.allowance(caller, contract) >= amount_in, 'Insufficient allowance');

            // Transfer input tokens from caller to contract
            input_token.transfer_from(caller, contract, amount_in);

            // Transfer output tokens from contract to recipient
            assert(
                output_token.balance_of(contract) >= amount_out, 'Insufficient contract balance',
            );
            output_token.transfer(recipient, amount_out);

            // Update pool reserves
            let new_reserve_in = reserve_in + amount_in;
            let new_reserve_out = reserve_out - amount_out;

            // Update the pool with the new reserves, maintaining the correct order
            if *token_in == pool.token_a {
                PrivateFunctions::_update(ref self, pool_key, new_reserve_in, new_reserve_out);
            } else {
                PrivateFunctions::_update(ref self, pool_key, new_reserve_out, new_reserve_in);
            }

            self
                .emit(
                    Swap {
                        sender: caller,
                        token_in: *token_in,
                        token_out: *token_out,
                        amount_in,
                        amount_out,
                        recipient,
                    },
                );

            self.reentrancy_guard.end();

            amount_in
        }

        fn add_supported_token(ref self: ContractState, token: ContractAddress) {
            ExternalImpl::add_supported_token_to_contract(ref self, token);
        }
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn add_supported_token_to_contract(ref self: ContractState, token: ContractAddress) {
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
