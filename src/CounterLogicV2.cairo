#[starknet::interface]
#[starknet::contract]
mod CounterLogicV2 {
    use inheritx::interfaces::ICounterLogicV2::ICounterLogicV2;
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress};

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
        CounterReset: CounterReset,
    }

    #[derive(Drop, starknet::Event)]
    struct CounterChanged {
        previous_value: u128,
        new_value: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct CounterReset {
        previous_value: u128,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.implementation_version.write('v2.0');
        self.counter.write(0);
    }

    #[abi(embed_v0)]
    impl CounterV2Impl of ICounterLogicV2<ContractState> {
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

        fn increment_by(ref self: ContractState, amount: u128) {
            self.ownable.assert_only_owner();
            let current = self.counter.read();
            let new_value = current + amount;
            self.counter.write(new_value);

            self.emit(CounterChanged { previous_value: current, new_value });
        }

        fn reset(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let current = self.counter.read();
            self.counter.write(0);

            self.emit(CounterReset { previous_value: current });
        }
    }
}
