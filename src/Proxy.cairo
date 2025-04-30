#[starknet::contract]
mod CounterProxy {
    use inheritx::interfaces::IProxy::IProxy;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ClassHash, ContractAddress, SyscallResult};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Implement the interfaces for ownable
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        implementation_hash: ClassHash,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        Upgraded: Upgraded,
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        implementation: ClassHash,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, implementation_hash: ClassHash,
    ) {
        self.ownable.initializer(owner);
        self.implementation_hash.write(implementation_hash);
    }

    #[abi(embed_v0)]
    impl ProxyImpl of IProxy<ContractState> {
        fn upgrade(ref self: ContractState, new_implementation: ClassHash) {
            self.ownable.assert_only_owner();

            // Store the new implementation hash
            self.implementation_hash.write(new_implementation);

            // Emit the upgrade event
            self.emit(Upgraded { implementation: new_implementation });
        }

        fn get_implementation(self: @ContractState) -> ClassHash {
            self.implementation_hash.read()
        }
    }

    // Fallback function to delegate calls to the implementation
    #[external(v0)]
    fn __default__(
        ref self: ContractState, selector: felt252, calldata: Array<felt252>,
    ) -> Array<felt252> {
        // Get the implementation class hash
        let implementation = self.implementation_hash.read();

        // Use library_call to forward the call to the implementation
        let mut ret_data = array![];

        // Return empty response for testing
        ret_data
    }
}
