use inheritx::interfaces::IInheritX::{IInheritXDispatcher, IInheritXDispatcherTrait};
use inheritx::types::ActivityType;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::contract_address_const;

fn setup() -> IInheritXDispatcher {
    let contract_class = declare("InheritX").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IInheritXDispatcher { contract_address }
}

#[test]
fn test_record_user_activity() {
    let inheritX = setup();
    // setup test data
    let user = contract_address_const::<'caller'>();
    let activity_type = ActivityType::Login;
    let details: felt252 = 'login by user';
    let ip_address: felt252 = '0.0.0.0';
    let device_info: felt252 = 'tester_device';

    // call record activity
    let activity_id: u256 = inheritX
        .record_user_activity(user, activity_type, details, ip_address, device_info);

    // assertion calls
    let activity = inheritX.get_user_activity(user, activity_id);
    assert(activity.device_info == device_info, 'invalid device info');
    assert(activity.ip_address == ip_address, 'invalid ip address');
    assert(activity.details == details, 'invalid details');
}
