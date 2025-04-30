#[starknet::contract]
mod CounterLogicV1 {
    use inheritx::interfaces::ICounterLogic::ICounterLogic;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::ContractAddress;
    use starknet::storage::{
        StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess,
    };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        counter: u128,
        implementation_version: felt252,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        CounterChanged: CounterChanged,
    }

    #[derive(Drop, starknet::Event)]
    struct CounterChanged {
        previous_value: u128,
        new_value: u128,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.implementation_version.write('v1.0');
        self.counter.write(0);
    }

    #[abi(embed_v0)]
    impl CounterImpl of ICounterLogic<ContractState> {
        fn get_counter(self: @ContractState) -> u128 {
            self.counter.read()
        }

        fn increment(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let current = self.counter.read();
            let new_value = current + 1;
            self.counter.write(new_value);

            self.emit(CounterChanged { previous_value: current, new_value });
        }

        fn decrement(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let current = self.counter.read();
            assert(current > 0, 'Counter cannot be negative');
            let new_value = current - 1;
            self.counter.write(new_value);

            self.emit(CounterChanged { previous_value: current, new_value });
        }

        fn get_version(self: @ContractState) -> felt252 {
            self.implementation_version.read()
        }
    }
}
