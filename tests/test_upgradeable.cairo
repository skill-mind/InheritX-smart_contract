#[cfg(test)]
mod tests {
    use core::result::ResultTrait;
    use inheritx::interfaces::ICounterLogic::{
        ICounterLogicDispatcher, ICounterLogicDispatcherTrait,
    };
    use inheritx::interfaces::ICounterLogicV2::{
        ICounterLogicV2Dispatcher, ICounterLogicV2DispatcherTrait,
    };
    use inheritx::interfaces::IProxy::{IProxyDispatcher, IProxyDispatcherTrait};
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, declare, get_class_hash, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use starknet::syscalls::deploy_syscall;
    use starknet::{ClassHash, ContractAddress, SyscallResultTrait, contract_address_const};

    fn deploy_counter_logic_v1() -> ClassHash {
        let owner = contract_address_const::<'owner'>();
        // Declare the V1 contract
        let declare_result = declare("CounterLogicV1").unwrap().contract_class();
        let (address, _) = declare_result.deploy(@array![owner.into()]).unwrap();

        get_class_hash(address)
    }

    fn deploy_counter_logic_v2() -> ClassHash {
        let owner = contract_address_const::<'owner'>();
        // Declare the V1 contract
        let declare_result = declare("CounterLogicV2").unwrap().contract_class();
        let (address, _) = declare_result.deploy(@array![owner.into()]).unwrap();

        get_class_hash(address)
    }

    fn deploy_counter_instance(class_hash: ClassHash) -> (ContractAddress, ContractAddress) {
        let owner = contract_address_const::<0x123>();

        // Deploy logic with constructor args
        let mut calldata = array![];
        calldata.append(owner.into());

        let (contract_address, _) = deploy_syscall(class_hash, 0, calldata.span(), false)
            .unwrap_syscall();

        (contract_address, owner)
    }

    fn deploy_proxy(implementation_hash: ClassHash) -> ContractAddress {
        let owner = contract_address_const::<0x123>();

        // Declare the proxy contract
        let declare_result = declare("CounterProxy").unwrap().contract_class();

        // Deploy with constructor args
        let mut calldata = ArrayTrait::<felt252>::new();
        calldata.append(owner.into());
        calldata.append(implementation_hash.into());

        // // Try with explicit conversion
        // let calldata_span = calldata.span();
        let (proxy_address, _) = declare_result.deploy(@calldata).unwrap();

        proxy_address
    }

    #[test]
    fn test_implementation_upgrade() {
        // Deploy initial logic contract (v1)
        let logic_hash_v1 = deploy_counter_logic_v1();
        let logic_address_v1 = deploy_counter_instance(logic_hash_v1);

        // Deploy proxy with logic implementation
        let proxy_address = deploy_proxy(logic_hash_v1);

        // Set caller to owner
        let owner = contract_address_const::<0x123>();
        start_cheat_caller_address(proxy_address, owner);

        // Check proxy implementation
        let proxy_dispatcher = IProxyDispatcher { contract_address: proxy_address };
        let initial_impl = proxy_dispatcher.get_implementation();
        assert(initial_impl == logic_hash_v1, 'Initial impl should be v1');

        // Deploy v2 implementation
        let logic_hash_v2 = deploy_counter_logic_v2();
        let logic_address_v2 = deploy_counter_instance(logic_hash_v2);

        // Upgrade proxy to new logic
        proxy_dispatcher.upgrade(logic_hash_v2);

        // Check implementation was updated
        let new_impl = proxy_dispatcher.get_implementation();
        assert(new_impl == logic_hash_v2, 'Implementation not updated');
    }


    #[test]
    fn test_functionality() {
        // Deploy v1 implementation
        let logic_hash_v1 = deploy_counter_logic_v1();
        let (logic_address_v1, owner) = deploy_counter_instance(logic_hash_v1);

        start_cheat_caller_address(logic_address_v1, owner);
        // Test v1 functionality
        let v1_dispatcher = ICounterLogicDispatcher { contract_address: logic_address_v1 };

        // Check initial version
        let version = v1_dispatcher.get_version();
        assert(version == 'v1.0', 'Wrong initial version');
    }

    #[test]
    fn test_increment_functionality() {
        // Deploy v1 implementation
        let logic_hash_v1 = deploy_counter_logic_v1();
        let (logic_address_v1, owner) = deploy_counter_instance(logic_hash_v1);

        start_cheat_caller_address(logic_address_v1, owner);
        // Test v1 functionality
        let v1_dispatcher = ICounterLogicDispatcher { contract_address: logic_address_v1 };

        // Increment counter
        v1_dispatcher.increment();
        v1_dispatcher.increment();

        // Check counter value
        let counter = v1_dispatcher.get_counter();
        assert(counter == 2, 'Counter should be 2');
    }

    #[test]
    fn test_deploy_v2_increment_by() {
        // Deploy v2 implementation
        let logic_hash_v2 = deploy_counter_logic_v2();
        let (logic_address_v2, owner) = deploy_counter_instance(logic_hash_v2);

        // Test v2 functionality
        let v2_dispatcher = ICounterLogicV2Dispatcher { contract_address: logic_address_v2 };

        // Check version
        let v2_version = v2_dispatcher.get_version();
        assert(v2_version == 'v2.0', 'Wrong v2 version');

        start_cheat_caller_address(logic_address_v2, owner);
        v2_dispatcher.increment_by(3);
        stop_cheat_caller_address(logic_address_v2);
        let counter_after = v2_dispatcher.get_counter();
        assert(counter_after == 3, 'Counter should be 3');
    }

    #[test]
    fn test_deploy_v2_reset() {
        // Deploy v2 implementation
        let logic_hash_v2 = deploy_counter_logic_v2();
        let (logic_address_v2, owner) = deploy_counter_instance(logic_hash_v2);

        // Test v2 functionality
        let v2_dispatcher = ICounterLogicV2Dispatcher { contract_address: logic_address_v2 };

        // Check version
        let v2_version = v2_dispatcher.get_version();
        assert(v2_version == 'v2.0', 'Wrong v2 version');

        start_cheat_caller_address(logic_address_v2, owner);
        v2_dispatcher.reset();
        stop_cheat_caller_address(logic_address_v2);
        let counter_reset = v2_dispatcher.get_counter();
        assert(counter_reset == 0, 'Counter should be reset to 0');
    }
}
