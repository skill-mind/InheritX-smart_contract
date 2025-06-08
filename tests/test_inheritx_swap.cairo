#[cfg(test)]
mod tests {
    use core::array::ArrayTrait;
    use core::num::traits::{Pow, Sqrt, Zero};
    use inheritx::InheritXSwap::InheritXSwap;
    use inheritx::InheritXSwap::InheritXSwap::{Event, LiquidityAdded, LiquidityRemoved, Swap};
    use inheritx::interfaces::IInheritXSwap::{
        IInheritXSwap, IInheritXSwapDispatcher, IInheritXSwapDispatcherTrait,
    };
    use inheritx::mocks::mock_erc20::{IIXTokenDispatcher, IIXTokenDispatcherTrait, IXToken};
    use openzeppelin::access::ownable::interface::{OwnableABIDispatcher, OwnableABIDispatcherTrait};
    use openzeppelin::token::erc20::interface::{
        ERC20ABIDispatcher, ERC20ABIDispatcherTrait, IERC20Dispatcher, IERC20DispatcherTrait,
    };
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, EventSpyTrait, declare,
        get_class_hash, spy_events, start_cheat_block_timestamp, start_cheat_caller_address,
        stop_cheat_block_timestamp, stop_cheat_caller_address, test_address,
    };
    use starknet::{ContractAddress, contract_address_const};

    fn owner() -> ContractAddress {
        contract_address_const::<'owner'>()
    }

    fn zero() -> ContractAddress {
        contract_address_const::<0>()
    }

    fn steph() -> ContractAddress {
        contract_address_const::<'steph'>()
    }

    fn john() -> ContractAddress {
        contract_address_const::<'john'>()
    }

    fn emarc() -> ContractAddress {
        contract_address_const::<'emarc'>()
    }

    pub const TOTAL_SUPPLY: u256 = 20_000_000_000_000_000_000_000;

    fn STRK_CONTRACT_ADDRESS() -> ContractAddress {
        contract_address_const::<
            0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d,
        >()
    }
    fn ETH_CONTRACT_ADDRESS() -> ContractAddress {
        contract_address_const::<
            0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7,
        >()
    }

    // ----- Helper functions -----

    fn deploy_erc20(
        name: ByteArray,
        decimals: u8,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress,
    ) -> ERC20ABIDispatcher {
        let token_contract_class = declare("IXToken").unwrap().contract_class();

        let mut constructor_args: Array<felt252> = ArrayTrait::new();
        name.serialize(ref constructor_args);
        decimals.serialize(ref constructor_args); // Decimals
        symbol.serialize(ref constructor_args);
        initial_supply.serialize(ref constructor_args);
        recipient.serialize(ref constructor_args);
        let (token_contract_address, _) = token_contract_class.deploy(@constructor_args).unwrap();

        ERC20ABIDispatcher { contract_address: token_contract_address }
    }

    // Helper function to deploy the tokens
    fn deploy_tokens() -> (ERC20ABIDispatcher, ERC20ABIDispatcher, ERC20ABIDispatcher) {
        let account = emarc();
        let eth = deploy_erc20("Ethereum", 18_u8, "ETH", TOTAL_SUPPLY, account); // 0x1
        let strk = deploy_erc20("Starknet", 18_u8, "STRK", TOTAL_SUPPLY, account); // 0x2
        let usdc = deploy_erc20("USD Coin", 6_u8, "USDC", TOTAL_SUPPLY, account); // 0x2

        (eth, strk, usdc)
    }

    fn deploy_inheritx_swap() -> (IInheritXSwapDispatcher, ContractAddress) {
        let contract_class = declare("InheritXSwap").unwrap().contract_class();
        let owner = owner();

        let constructor_args = array![owner.into()];

        let (contract_address, _) = contract_class.deploy(@constructor_args).unwrap();

        (IInheritXSwapDispatcher { contract_address }, contract_address)
    }

    fn mint_and_approve(
        token: ERC20ABIDispatcher,
        owner: ContractAddress,
        user: ContractAddress,
        amount: u256,
        spender: ContractAddress,
    ) {
        // Mint tokens to user
        let mint_dispatcher = IIXTokenDispatcher { contract_address: token.contract_address };
        start_cheat_caller_address(token.contract_address, owner);
        mint_dispatcher.mint(user, amount);
        stop_cheat_caller_address(token.contract_address);

        // Approve spender to use tokens
        start_cheat_caller_address(token.contract_address, user);
        token.approve(spender, amount);
        stop_cheat_caller_address(token.contract_address);
    }

    #[test]
    fn test_constructor_sets_owner() {
        let owner = owner();
        let (_, contract_address) = deploy_inheritx_swap();
        let ownable_dispatcher = OwnableABIDispatcher { contract_address };

        let retrieved_owner = ownable_dispatcher.owner();

        assert!(retrieved_owner == owner, "Constructor: Owner not set");
    }

    #[test]
    fn test_initial_state() {
        let (swap_dispatcher, _) = deploy_inheritx_swap();

        let supported_tokens = swap_dispatcher.get_supported_tokens();

        assert(supported_tokens.len() == 0, 'Initial token count should be 0');
    }

    #[test]
    #[should_panic(expected: ('INSUFFICIENT_CALLER_BALANCE',))]
    fn test_add_liquidity_insufficient_token_balance() {
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let user = steph();

        // Prepare user for adding liquidity
        start_cheat_caller_address(swap_address, user);
        eth.approve(swap_address, 1000_u256);
        strk.approve(swap_address, 2000_u256);

        // Add initial liquidity
        let deadline = 1000_u64;
        start_cheat_block_timestamp(swap_address, 500);
        let (amount_a, amount_b) = swap_dispatcher
            .add_liquidity(
                eth.contract_address,
                strk.contract_address,
                1000_u256, // amount_a_desired
                2000_u256, // amount_b_desired
                900_u256, // amount_a_min
                1800_u256, // amount_b_min
                user,
                deadline,
            );
    }

    #[test]
    fn test_create_pool() {
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let token_owner = emarc();

        // Prepare user for adding liquidity
        start_cheat_caller_address(eth.contract_address, token_owner);
        eth.approve(swap_address, 1000_u256);
        stop_cheat_caller_address(eth.contract_address);

        start_cheat_caller_address(strk.contract_address, token_owner);
        strk.approve(swap_address, 2000_u256);
        stop_cheat_caller_address(strk.contract_address);

        start_cheat_caller_address(swap_address, token_owner);

        // Add initial liquidity
        let deadline = 1000_u64;
        start_cheat_block_timestamp(swap_address, 500);
        let (amount_a, amount_b) = swap_dispatcher
            .add_liquidity(
                eth.contract_address,
                strk.contract_address,
                1000_u256, // amount_a_desired
                2000_u256, // amount_b_desired
                900_u256, // amount_a_min
                1800_u256, // amount_b_min
                token_owner,
                deadline,
            );

        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // Verify amounts added
        assert(amount_a == 1000_u256, 'Wrong ETH amount added');
        assert(amount_b == 2000_u256, 'Wrong STRK amount added');

        // Verify pool was created
        let (reserve_a, reserve_b) = swap_dispatcher
            .get_liquidity(eth.contract_address, strk.contract_address);
        assert(reserve_a == 1000_u256, 'Wrong ETH reserve');
        assert(reserve_b == 2000_u256, 'Wrong STRK reserve');
    }

    #[test]
    fn test_add_liquidity_to_existing_pool() {
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let user1 = steph();
        let user2 = john();
        let token_owner = emarc();

        // Mint and approve tokens for both users
        mint_and_approve(eth, token_owner, user1, 1000_u256, swap_address);
        mint_and_approve(strk, token_owner, user1, 2000_u256, swap_address);
        mint_and_approve(eth, token_owner, user2, 2000_u256, swap_address);
        mint_and_approve(strk, token_owner, user2, 4000_u256, swap_address);

        // User1 creates pool
        start_cheat_caller_address(swap_address, user1);
        start_cheat_block_timestamp(swap_address, 500);
        swap_dispatcher
            .add_liquidity(
                eth.contract_address,
                strk.contract_address,
                1000_u256,
                2000_u256,
                900_u256,
                1800_u256,
                user1,
                1000_u64,
            );
        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // User2 adds liquidity
        start_cheat_caller_address(swap_address, user2);
        start_cheat_block_timestamp(swap_address, 600);

        let (amount_a, amount_b) = swap_dispatcher
            .add_liquidity(
                eth.contract_address,
                strk.contract_address,
                2000_u256,
                4000_u256,
                1800_u256,
                3600_u256,
                user2,
                1000_u64,
            );
        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // Verify amounts added (should maintain ratio)
        assert(amount_a == 2000_u256, 'Incorrect ETH amount added');
        assert(amount_b == 4000_u256, 'Incorrect STRK amount added');

        // Verify reserves updated correctly
        let (reserve_a, reserve_b) = swap_dispatcher
            .get_liquidity(eth.contract_address, strk.contract_address);
        assert!(reserve_a == 3000_u256, "Incorrect ETH reserve after addition");
        assert!(reserve_b == 6000_u256, "Incorrect STRK reserve after addition");
    }

    #[test]
    fn test_remove_liquidity() {
        // Setup
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let user = steph();
        let token_owner = emarc();

        // Mint and approve
        mint_and_approve(eth, token_owner, user, 1000_u256, swap_address);
        mint_and_approve(strk, token_owner, user, 2000_u256, swap_address);

        // Add liquidity
        start_cheat_caller_address(swap_address, user);
        start_cheat_block_timestamp(swap_address, 500);
        let (_, _) = swap_dispatcher
            .add_liquidity(
                eth.contract_address,
                strk.contract_address,
                1000_u256,
                2000_u256,
                900_u256,
                1800_u256,
                user,
                1000_u64,
            );

        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // Get pool info
        let (reserve_a, reserve_b) = swap_dispatcher
            .get_liquidity(eth.contract_address, strk.contract_address);
        let total_supply: u256 = (reserve_a * reserve_b).sqrt().into(); // ≈1414

        // Calculate expected amounts for 500 shares
        let expected_eth = 500_u256 * reserve_a / total_supply; // ≈353
        let expected_strk = 500_u256 * reserve_b / total_supply; // ≈707

        // Get initial balances
        let initial_eth = eth.balance_of(user);
        let initial_strk = strk.balance_of(user);

        // Remove liquidity with proper minimums
        start_cheat_caller_address(swap_address, user);
        start_cheat_block_timestamp(swap_address, 600);
        let (removed_eth, removed_strk) = swap_dispatcher
            .remove_liquidity(
                eth.contract_address,
                strk.contract_address,
                500_u256, // liquidity to remove
                expected_eth - 1, // min ETH (slightly less than expected)
                expected_strk - 1, // min STRK
                user,
                1000_u64,
            );
        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // Verify amounts removed (with ≈5% tolerance for rounding)
        assert(
            removed_eth >= expected_eth
                * 95_u256
                / 100_u256 && removed_eth <= expected_eth
                * 105_u256
                / 100_u256,
            'Wrong ETH amount removed',
        );
        assert(
            removed_strk >= expected_strk
                * 95_u256
                / 100_u256 && removed_strk <= expected_strk
                * 105_u256
                / 100_u256,
            'Wrong STRK amount removed',
        );

        // Verify reserves updated
        let (new_reserve_a, new_reserve_b) = swap_dispatcher
            .get_liquidity(eth.contract_address, strk.contract_address);
        assert!(new_reserve_a == reserve_a - removed_eth, "Wrong ETH reserve after removal");
        assert!(new_reserve_b == reserve_b - removed_strk, "Wrong STRK reserve after removal");

        // Check final balances
        assert!(eth.balance_of(user) == initial_eth + removed_eth, "User should receive ETH back");
        assert!(
            strk.balance_of(user) == initial_strk + removed_strk, "User should receive STRK back",
        );
    }

    #[test]
    #[should_panic(expected: ('INVALID_RATIO',))]
    fn test_add_liquidity_invalid_ratio() {
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let user = steph();
        let token_owner = emarc();

        // Setup pool with initial 1:2 ratio
        mint_and_approve(eth, token_owner, user, 2000_u256, swap_address);
        mint_and_approve(strk, token_owner, user, 4000_u256, swap_address);

        start_cheat_caller_address(swap_address, user);
        start_cheat_block_timestamp(swap_address, 500);
        swap_dispatcher
            .add_liquidity(
                eth.contract_address,
                strk.contract_address,
                1000_u256,
                2000_u256,
                900_u256,
                1800_u256,
                user,
                1000_u64,
            );
        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // Attempt to add liquidity with wrong ratio (should panic)
        start_cheat_caller_address(swap_address, user);
        start_cheat_block_timestamp(swap_address, 600);
        swap_dispatcher
            .add_liquidity(
                eth.contract_address,
                strk.contract_address,
                1000_u256,
                3000_u256, // Wrong ratio (1:3 instead of 1:2)
                900_u256,
                2700_u256,
                user,
                1000_u64,
            );
    }

    #[test]
    fn test_liquidity_events() {
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let user = steph();
        let token_owner = emarc();

        // Setup pool
        mint_and_approve(eth, token_owner, user, 1000_u256, swap_address);
        mint_and_approve(strk, token_owner, user, 2000_u256, swap_address);

        // Start event spy
        let mut spy = spy_events();

        // Add liquidity
        start_cheat_caller_address(swap_address, user);
        start_cheat_block_timestamp(swap_address, 500);
        let (amount_a, amount_b) = swap_dispatcher
            .add_liquidity(
                eth.contract_address,
                strk.contract_address,
                1000_u256,
                2000_u256,
                900_u256,
                1800_u256,
                user,
                1000_u64,
            );
        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // Get pool key
        let pool_key = swap_dispatcher
            .get_ordered_token_pair(eth.contract_address, strk.contract_address);

        // Check LiquidityAdded event
        let expected_liquidity = (1000_u256 * 2000_u256).sqrt().into();
        let expected_liquid_added_event = InheritXSwap::Event::LiquidityAdded(
            LiquidityAdded {
                provider: user,
                token_a: pool_key.token_a,
                token_b: pool_key.token_b,
                amount_a: amount_a,
                amount_b: amount_b,
                liquidity: expected_liquidity,
            },
        );

        // --- Remove Liquidity Section ---

        start_cheat_caller_address(swap_address, user);
        start_cheat_block_timestamp(swap_address, 600);
        let (removed_eth, removed_strk) = swap_dispatcher
            .remove_liquidity(
                eth.contract_address,
                strk.contract_address,
                500_u256, // liquidity to remove
                350_u256,
                700_u256,
                user,
                1000_u64,
            );

        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // Verify LiquidityRemoved event
        let expected_remove_event = LiquidityRemoved {
            recipient: user,
            token_a: pool_key.token_a,
            token_b: pool_key.token_b,
            amount_a: removed_eth,
            amount_b: removed_strk,
            liquidity: 500_u256,
        };

        // Get all events
        let captured_events = spy.get_events();
        assert(captured_events.events.len() == 8, 'Expected 4 events');
        // Check event emission with exact matching
    // spy.assert_emitted(@array![
    //     (swap_address, expected_liquid_added_event),
    //     (swap_address, expected_remove_event)
    // ]);
    }

    #[test]
    #[should_panic(expected: ('INSUFFICIENT_AMOUNT_B',))]
    fn test_remove_liquidity_insufficient_amount() {
        // Setup
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let user = steph();
        let token_owner = emarc();

        // Mint and approve tokens
        mint_and_approve(eth, token_owner, user, 1000_u256, swap_address);
        mint_and_approve(strk, token_owner, user, 2000_u256, swap_address);

        // Add initial liquidity
        start_cheat_caller_address(swap_address, user);
        start_cheat_block_timestamp(swap_address, 500);
        let (_, _) = swap_dispatcher
            .add_liquidity(
                eth.contract_address,
                strk.contract_address,
                1000_u256,
                2000_u256,
                900_u256,
                1800_u256,
                user,
                1000_u64,
            );
        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // Get pool info
        let (reserve_a, reserve_b) = swap_dispatcher
            .get_liquidity(eth.contract_address, strk.contract_address);
        let total_supply = (reserve_a * reserve_b).sqrt().into(); // Total supply of LP tokens

        // Calculate expected amounts for 500 shares
        let expected_eth = 500_u256 * reserve_a / total_supply;
        let expected_strk = 500_u256 * reserve_b / total_supply;

        // Attempt to remove liquidity with minimums set HIGHER than expected returns
        start_cheat_caller_address(swap_address, user);
        start_cheat_block_timestamp(swap_address, 600);
        swap_dispatcher
            .remove_liquidity(
                eth.contract_address,
                strk.contract_address,
                500_u256,
                expected_eth + 1_u256, // Set min ETH higher than expected
                expected_strk,
                user,
                1000_u64,
            );
    }

    #[test]
    #[should_panic(expected: ('DEADLINE_EXPIRED',))]
    fn test_deadline_expired() {
        // Setup
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let user = steph();
        let token_owner = emarc();

        // Mint and approve tokens
        mint_and_approve(eth, token_owner, user, 1000_u256, swap_address);
        mint_and_approve(strk, token_owner, user, 2000_u256, swap_address);

        // Set block timestamp to 1000
        start_cheat_block_timestamp(swap_address, 1000);

        start_cheat_caller_address(swap_address, user);
        swap_dispatcher
            .add_liquidity(
                eth.contract_address,
                strk.contract_address,
                1000_u256,
                2000_u256,
                900_u256,
                1800_u256,
                user,
                999_u64 // Deadline already passed
            );
    }

    #[test]
    fn test_get_swap_rate_logic() {
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let user = steph();
        let token_owner = emarc();

        // Mint & approve 1000 ETH and 2000 STRK to pool-creator
        mint_and_approve(eth.clone(), token_owner, user, 1000_u256, swap_address);
        mint_and_approve(strk.clone(), token_owner, user, 2000_u256, swap_address);

        // Create pool with 1000 ETH / 2000 STRK
        start_cheat_caller_address(swap_address, user);
        start_cheat_block_timestamp(swap_address, 500);
        let (_amt_a, _amt_b) = swap_dispatcher

    fn test_swap_tokens_for_exact_tokens_typical_case() {
        // Setup
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let token_owner = emarc();
        let sender = steph();
        let recipient = john();

        let mut event_spy = spy_events();

        // Add tokens to supported list
        start_cheat_caller_address(swap_address, owner());
        swap_dispatcher.add_supported_token(eth.contract_address);
        swap_dispatcher.add_supported_token(strk.contract_address);
        stop_cheat_caller_address(swap_address);

        // Setup liquidity pool with 1000 ETH and 2000 STRK
        mint_and_approve(eth, token_owner, owner(), 1000_u256, swap_address);
        mint_and_approve(strk, token_owner, owner(), 2000_u256, swap_address);

        start_cheat_caller_address(swap_address, owner());
        start_cheat_block_timestamp(swap_address, 500);

        swap_dispatcher
            .add_liquidity(
                eth.contract_address,
                strk.contract_address,
                1000_u256, // amount_a_desired
                2000_u256, // amount_b_desired
                900_u256, // amount_a_min
                1800_u256, // amount_b_min
                user,
                1000_u64 // deadline
            );
        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // Now query: swap 100 ETH → STRK
        // expected_out = floor((100 * 2000) / (1000 + 100)) = floor(200000 / 1100) = 181
        let amount_out: u256 = swap_dispatcher
            .get_swap_rate(eth.contract_address, strk.contract_address, 100_u256);
        assert!(amount_out == 181_u256, "Expected 181 STRK, got {}", amount_out);
    }

    #[test]
    #[should_panic(expected: ('INVALID_TOKENS',))]
    fn test_get_swap_rate_invalid_tokens() {
        let (swap_dispatcher, _swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();

        // Case A: token_in == 0
        swap_dispatcher.get_swap_rate(zero(), strk.contract_address, 100_u256);
    }

    #[test]
    #[should_panic(expected: ('IDENTICAL_TOKENS',))]
    fn test_get_swap_rate_identical_tokens() {
        let (swap_dispatcher, _swap_address) = deploy_inheritx_swap();
        let (eth, _strk, _) = deploy_tokens();

        // Both token_in and token_out are the same non-zero address
        swap_dispatcher.get_swap_rate(eth.contract_address, eth.contract_address, 50_u256);
    }

    #[test]
    #[should_panic(expected: ('INVALID_AMOUNT_IN',))]
    fn test_get_swap_rate_amount_zero() {
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let user = steph();
        let token_owner = emarc();

        // set up a valid pool
        mint_and_approve(eth.clone(), token_owner, user, 500_u256, swap_address);
        mint_and_approve(strk.clone(), token_owner, user, 1000_u256, swap_address);

        // Create pool with 500 ETH / 1000 STRK
        start_cheat_caller_address(swap_address, user);
        start_cheat_block_timestamp(swap_address, 400);
                owner(),
                1000_u64 // deadline
            );

        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // Setup sender with tokens for swap
        mint_and_approve(eth, token_owner, sender, 200_u256, swap_address);

        // Create path for swap
        let mut path = ArrayTrait::new();
        path.append(eth.contract_address);
        path.append(strk.contract_address);

        // Execute swap
        start_cheat_caller_address(swap_address, sender);
        start_cheat_block_timestamp(swap_address, 600);

        let amount_in = swap_dispatcher
            .swap_tokens_for_exact_tokens(
                50_u256, // Exact amount of STRK to receive
                200_u256, // Maximum ETH willing to spend
                path,
                recipient,
                1000_u64 // deadline
            );

        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // Verify results
        assert(amount_in > 0, 'Input amount should be positive');
        assert(amount_in < 200_u256, 'Should use less than max input');

        // Check balances
        assert(eth.balance_of(sender) == 200_u256 - amount_in, 'Incorrect sender ETH balance');
        assert(strk.balance_of(recipient) == 50_u256, 'Recipient should have 50 STRK');

        // Verify pool state
        let (reserve_eth, reserve_strk) = swap_dispatcher
            .get_liquidity(eth.contract_address, strk.contract_address);
        assert(reserve_eth == 1000_u256 + amount_in, 'Incorrect ETH reserve');
        assert(reserve_strk == 2000_u256 - 50_u256, 'Incorrect STRK reserve');

        event_spy
            .assert_emitted(
                @array![
                    (
                        swap_dispatcher.contract_address,
                        Event::Swap(
                            Swap {
                                sender,
                                token_in: eth.contract_address,
                                token_out: strk.contract_address,
                                amount_in,
                                amount_out: 50_u256,
                                recipient,
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    #[should_panic(expected: ('Invalid amount: must be > 0',))]
    fn test_swap_tokens_for_exact_tokens_zero_amount() {
        // Setup
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let sender = steph();

        // Add tokens to supported list
        start_cheat_caller_address(swap_address, owner());
        swap_dispatcher.add_supported_token(eth.contract_address);
        swap_dispatcher.add_supported_token(strk.contract_address);
        stop_cheat_caller_address(swap_address);

        // Create path for swap
        let mut path = ArrayTrait::new();
        path.append(eth.contract_address);
        path.append(strk.contract_address);

        // Execute swap with zero amount_out (should fail)
        start_cheat_caller_address(swap_address, sender);
        start_cheat_block_timestamp(swap_address, 600);

        swap_dispatcher
            .swap_tokens_for_exact_tokens(
                0_u256, // Zero amount to receive (should fail)
                100_u256, // Maximum input
                path,
                john(),
                1000_u64 // deadline
            );
    }

    #[test]
    #[should_panic(expected: ('Excessive input amount',))]
    fn test_swap_tokens_for_exact_tokens_excessive_input() {
        // Setup
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let token_owner = emarc();
        let sender = steph();
        let recipient = john();

        // Add tokens to supported list
        start_cheat_caller_address(swap_address, owner());
        swap_dispatcher.add_supported_token(eth.contract_address);
        swap_dispatcher.add_supported_token(strk.contract_address);
        stop_cheat_caller_address(swap_address);

        // Setup liquidity pool with 1000 ETH and 2000 STRK
        mint_and_approve(eth, token_owner, owner(), 1000_u256, swap_address);
        mint_and_approve(strk, token_owner, owner(), 2000_u256, swap_address);

        start_cheat_caller_address(swap_address, owner());
        start_cheat_block_timestamp(swap_address, 500);
        
        swap_dispatcher
            .add_liquidity(
                eth.contract_address,
                strk.contract_address,
                500_u256,
                1000_u256,
                450_u256,
                900_u256,
                user,
                1000_u64,
            );
        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);
        // Now query: swap 0 ETH → STRK
        // This should panic with "INVALID_AMOUNT_IN"
        swap_dispatcher.get_swap_rate(eth.contract_address, strk.contract_address, 0_u256);
    }

    #[test]
    #[should_panic(expected: ('TOKENS_NOT_SUPPORTED',))]
    fn test_get_swap_rate_unsupported_tokens() {
        let (swap_dispatcher, _swap_address) = deploy_inheritx_swap();
        let (_eth, strk, usdc) = deploy_tokens();

        swap_dispatcher.get_swap_rate(usdc.contract_address, strk.contract_address, 100_u256);
                1000_u256, // amount_a_desired
                2000_u256, // amount_b_desired
                900_u256, // amount_a_min
                1800_u256, // amount_b_min
                owner(),
                1000_u64 // deadline
            );

        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // Setup sender with tokens for swap
        mint_and_approve(eth, token_owner, sender, 200_u256, swap_address);

        // Create path for swap
        let mut path = ArrayTrait::new();
        path.append(eth.contract_address);
        path.append(strk.contract_address);

        // Execute swap with insufficient max_amount_in
        start_cheat_caller_address(swap_address, sender);
        start_cheat_block_timestamp(swap_address, 600);

        // Calculate required input for 100 STRK (should be more than 30)
        swap_dispatcher
            .swap_tokens_for_exact_tokens(
                100_u256, // Amount of STRK to receive
                30_u256, // Maximum ETH willing to spend (too low)
                path,
                recipient,
                1000_u64 // deadline
            );
    }

    #[test]
    #[should_panic(expected: ('Deadline exceeded',))]
    fn test_swap_tokens_for_exact_tokens_expired_deadline() {
        // Setup
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let sender = steph();

        // Add tokens to supported list
        start_cheat_caller_address(swap_address, owner());
        swap_dispatcher.add_supported_token(eth.contract_address);
        swap_dispatcher.add_supported_token(strk.contract_address);
        stop_cheat_caller_address(swap_address);

        // Create path for swap
        let mut path = ArrayTrait::new();
        path.append(eth.contract_address);
        path.append(strk.contract_address);

        // Execute swap with expired deadline
        start_cheat_caller_address(swap_address, sender);
        start_cheat_block_timestamp(swap_address, 1000); // Current time is 1000

        swap_dispatcher
            .swap_tokens_for_exact_tokens(
                50_u256, // Amount to receive
                200_u256, // Maximum input
                path,
                john(),
                500_u64 // Deadline in the past (500 < 1000)
            );
    }
    #[test]
    #[should_panic(expected: ('Invalid path: need min 2 tokens',))]
    fn test_swap_tokens_for_exact_tokens_invalid_path() {
        // Setup
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let sender = steph();

        // Create empty path for swap (invalid)
        let path = ArrayTrait::new();

        // Execute swap with invalid path
        start_cheat_caller_address(swap_address, sender);
        start_cheat_block_timestamp(swap_address, 600);

        swap_dispatcher
            .swap_tokens_for_exact_tokens(
                50_u256, // Amount to receive
                200_u256, // Maximum input
                path, // Empty path (invalid)
                john(),
                1000_u64 // deadline
            );
    }
    #[test]
    #[should_panic(expected: ('Unsupported token in path',))]
    fn test_swap_tokens_for_exact_tokens_unsupported_token() {
        // Setup
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let sender = steph();

        // Create path with unsupported tokens
        let mut path = ArrayTrait::new();
        path.append(eth.contract_address);
        path.append(strk.contract_address);

        // Execute swap with unsupported tokens
        start_cheat_caller_address(swap_address, sender);
        start_cheat_block_timestamp(swap_address, 600);

        swap_dispatcher
            .swap_tokens_for_exact_tokens(
                50_u256, // Amount to receive
                200_u256, // Maximum input
                path, // Path with unsupported tokens
                john(),
                1000_u64 // deadline
            );
    }

    #[test]
    #[should_panic(expected: ('Pool not found',))]
    fn test_swap_tokens_for_exact_tokens_no_pool() {
        // Setup
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, strk, _) = deploy_tokens();
        let sender = steph();

        // Add tokens to supported list but don't create a pool
        start_cheat_caller_address(swap_address, owner());
        swap_dispatcher.add_supported_token(eth.contract_address);
        swap_dispatcher.add_supported_token(strk.contract_address);
        stop_cheat_caller_address(swap_address);

        // Create path for swap
        let mut path = ArrayTrait::new();
        path.append(eth.contract_address);
        path.append(strk.contract_address);

        // Execute swap without a pool
        start_cheat_caller_address(swap_address, sender);
        start_cheat_block_timestamp(swap_address, 600);

        swap_dispatcher
            .swap_tokens_for_exact_tokens(
                50_u256, // Amount to receive
                200_u256, // Maximum input
                path,
                john(),
                1000_u64 // deadline
            );
    }

    #[test]
    fn test_swap_tokens_for_exact_tokens_with_different_decimals() {
        // Setup
        let (swap_dispatcher, swap_address) = deploy_inheritx_swap();
        let (eth, _, usdc) = deploy_tokens();
        let token_owner = emarc();
        let sender = steph();
        let recipient = john();

        // Add tokens to supported list
        start_cheat_caller_address(swap_address, owner());
        swap_dispatcher.add_supported_token(eth.contract_address);
        swap_dispatcher.add_supported_token(usdc.contract_address);
        stop_cheat_caller_address(swap_address);

        // USDC has 6 decimals vs ETH's 18
        let eth_amount = 1000_u256 * 10_u256.pow(18);
        let usdc_amount = 2000_u256 * 10_u256.pow(6);

        // Setup liquidity pool with different decimal tokens
        mint_and_approve(eth, token_owner, owner(), eth_amount, swap_address);
        mint_and_approve(usdc, token_owner, owner(), usdc_amount, swap_address);

        start_cheat_caller_address(swap_address, owner());
        start_cheat_block_timestamp(swap_address, 500);

        swap_dispatcher
            .add_liquidity(
                eth.contract_address,
                usdc.contract_address,
                eth_amount,
                usdc_amount,
                eth_amount * 9 / 10,
                usdc_amount * 9 / 10,
                owner(),
                1000_u64,
            );

        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // Setup sender with tokens for swap
        let sender_eth = 100_u256 * 10_u256.pow(18);
        mint_and_approve(eth, token_owner, sender, sender_eth, swap_address);

        // Create path for swap
        let mut path = ArrayTrait::new();
        path.append(eth.contract_address);
        path.append(usdc.contract_address);

        // Execute swap
        start_cheat_caller_address(swap_address, sender);
        start_cheat_block_timestamp(swap_address, 600);

        let usdc_out = 100_u256 * 10_u256.pow(6); // 100 USDC
        let max_eth_in = 60_u256 * 10_u256.pow(18); // 60 ETH

        let amount_in = swap_dispatcher
            .swap_tokens_for_exact_tokens(usdc_out, max_eth_in, path, recipient, 1000_u64);

        stop_cheat_block_timestamp(swap_address);
        stop_cheat_caller_address(swap_address);

        // Verify results
        assert(amount_in > 0, 'Input amount should be positive');
        assert(amount_in < max_eth_in, 'Should use less than max input');

        // Check balances
        assert(eth.balance_of(sender) == sender_eth - amount_in, 'Incorrect sender ETH balance');
        assert(usdc.balance_of(recipient) == usdc_out, 'Should have exact USDC');

        // Verify pool state
        let (reserve_eth, reserve_usdc) = swap_dispatcher
            .get_liquidity(eth.contract_address, usdc.contract_address);
        assert(reserve_eth == eth_amount + amount_in, 'Incorrect ETH reserve');
        assert(reserve_usdc == usdc_amount - usdc_out, 'Incorrect USDC reserve');
    }
}

