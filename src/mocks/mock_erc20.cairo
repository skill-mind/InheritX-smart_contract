use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20Metadata<TContractState> {
    // IERC20Metadata
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn decimals(self: @TContractState) -> u8;
}

#[starknet::interface]
pub trait IIXToken<TContractState> {
    // Add the external mint function for testing purposes
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
}

#[starknet::contract]
pub mod IXToken {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    // use openzeppelin::token::erc20::interface;
    use starknet::ContractAddress;
    use starknet::storage::*;
    use super::{IERC20Metadata, IIXToken};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        decimals: u8,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        decimals: u8,
        symbol: ByteArray,
        supply: u256,
        recipient: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);

        // Mint tokens to user first
        self.erc20.mint(recipient, supply);
        self.decimals.write(decimals);
    }

    #[abi(embed_v0)]
    impl ERC20CustomMetadataImpl of IERC20Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc20.ERC20_name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            // self.erc20.symbol()
            self.erc20.ERC20_symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }
    }

    #[abi(embed_v0)]
    impl IXTokenTestImpl of IIXToken<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.erc20.mint(recipient, amount);
        }
    }
}
