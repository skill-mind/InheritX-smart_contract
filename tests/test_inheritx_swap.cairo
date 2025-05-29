#[cfg(test)]
mod tests {
    use core::array::ArrayTrait;
    use core::num::traits::{Sqrt, Zero};
    use inheritx::InheritXSwap::InheritXSwap;
    use inheritx::InheritXSwap::InheritXSwap::{LiquidityAdded, LiquidityRemoved};
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

        // Attempt to add liquidity with deadline in the past (999)
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
}
