use inheritx::interfaces::IInheritX::{IInheritX, IInheritXDispatcher, IInheritXDispatcherTrait};
use inheritx::interfaces::IInheritX::AssetAllocation; 
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use starknet::class_hash::ClassHash;
use starknet::contract_address::contract_address_const;
use starknet::testing::{set_caller_address, set_contract_address};
use snforge_std::{cheat_caller_address, CheatSpan};

fn setup() -> ContractAddress {
    let declare_result = declare("InheritX");
    assert(declare_result.is_ok(), 'Contract declaration failed');

    let contract_class = declare_result.unwrap().contract_class();
    let mut calldata = array![];

    let deploy_result = contract_class.deploy(@calldata);
    assert(deploy_result.is_ok(), 'Contract deployment failed');

    let (contract_address, _) = deploy_result.unwrap();

    (contract_address)
}

#[test]
fn test_initial_data() {
    let contract_address = setup();

    let dispatcher = IInheritXDispatcher { contract_address };

    // Ensure dispatcher methods exist
    let deployed = dispatcher.test_deployment();

    assert(deployed == true, 'deployment failed');
}

#[test]
fn test_create_inheritance_plan() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
    let guardians: Array<ContractAddress> = array![benefactor, beneficiary];
    let assets: Array<AssetAllocation> = array![AssetAllocation { token: benefactor, amount: 1000, percentage: 50 }, AssetAllocation { token: beneficiary, amount: 1000, percentage: 50 }];

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

    // Call create_inheritance_plan
    let plan_id = dispatcher.create_inheritance_plan(1000, 2, guardians, assets);

    assert(plan_id == 1, 'create_inheritance_plan failed');
    let plan = dispatcher.get_inheritance_plan(plan_id);
    assert(plan.owner == benefactor, 'owner mismatch');
    assert(plan.time_lock_period == 1000, 'time_lock_period mismatch');
    assert(plan.required_guardians == 2, 'required_guardians mismatch');
    assert(plan.is_active == true, 'is_active mismatch');
    assert(plan.is_claimed == false, 'is_claimed mismatch');
    assert(plan.total_value == 2000, 'total_value mismatch');
}

#[test]
#[should_panic(expected: ('No assets specified',))]
fn test_create_inheritance_plan_no_assets() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let guardians: Array<ContractAddress> = array![benefactor];

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);

    // Test with no assets
    let assets: Array<AssetAllocation> = array![];
    dispatcher.create_inheritance_plan(1000, 1, guardians, assets);
}

#[test]
#[should_panic(expected: ('Timelock too short',))]
fn test_create_inheritance_plan_timelock_too_short() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
    let guardians: Array<ContractAddress> = array![benefactor];
    let assets: Array<AssetAllocation> = array![AssetAllocation { token: benefactor, amount: 1000, percentage: 50 }, AssetAllocation { token: beneficiary, amount: 1000, percentage: 50 }];
    
    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);
    
    dispatcher.create_inheritance_plan(0, 1, guardians, assets);
}

// #[test]
// #[should_panic(expected: ('Timelock too long',))]
// fn test_create_inheritance_plan_timelock_too_long() {
//     let contract_address = setup();
//     let dispatcher = IInheritXDispatcher { contract_address };
//     let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
//     let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
//     let guardians: Array<ContractAddress> = array![benefactor];
//     let assets: Array<AssetAllocation> = array![AssetAllocation { token: benefactor, amount: 1000, percentage: 50 }, AssetAllocation { token: beneficiary, amount: 1000, percentage: 50 }];
    
//     // Ensure the caller is the admin
//     cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);
    
//     dispatcher.create_inheritance_plan(366 days, 1, guardians, assets);
// }

#[test]
#[should_panic(expected: ('Too few guardians',))]
fn test_create_inheritance_plan_too_few_guardians() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
    let assets: Array<AssetAllocation> = array![AssetAllocation { token: benefactor, amount: 1000, percentage: 50 }, AssetAllocation { token: beneficiary, amount: 1000, percentage: 50 }];
    
    // Create an empty guardians array (assuming min_guardians > 0)
    let guardians: Array<ContractAddress> = array![];
    
    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);
    
    // This should fail because there are no guardians
    dispatcher.create_inheritance_plan(1000, 1, guardians, assets);
}

// #[test]
// #[should_panic(expected: ('Too many guardians',))]
// fn test_create_inheritance_plan_too_many_guardians() {
//     let contract_address = setup();
//     let dispatcher = IInheritXDispatcher { contract_address };
//     let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    
//     // Create too many guardians (assuming max_guardians is set to a reasonable value)
//     let mut guardians: Array<ContractAddress> = array![];
//     // Add more guardians than max_guardians
//     guardians.append(contract_address_const::<'guardian1'>);
//     guardians.append(contract_address_const::<'guardian2'>);
//     guardians.append(contract_address_const::<'guardian3'>);
//     guardians.append(contract_address_const::<'guardian4'>);
//     guardians.append(contract_address_const::<'guardian5'>);
//     guardians.append(contract_address_const::<'guardian6'>); // Assuming max_guardians is 5
    
//     // Create a valid asset
//     let asset = AssetAllocation { 
//         asset_type: 0, 
//         asset_address: contract_address_const::<'asset'>, 
//         amount: 1000 
//     };
//     let assets: Array<AssetAllocation> = array![asset];
    
//     // Ensure the caller is the admin
//     cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);
    
//     // This should fail because there are too many guardians
//     dispatcher.create_inheritance_plan(1000, 1, guardians, assets);
// }

#[test]
#[should_panic(expected: ('Invalid required guardians',))]
fn test_create_inheritance_plan_invalid_required_guardians() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
    let guardians: Array<ContractAddress> = array![benefactor];
    let assets: Array<AssetAllocation> = array![AssetAllocation { token: benefactor, amount: 1000, percentage: 50 }, AssetAllocation { token: beneficiary, amount: 1000, percentage: 50 }];
    
    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);
    
    // This should fail because required guardians (3) > total guardians (1)
    dispatcher.create_inheritance_plan(1000, 3, guardians, assets);
}

#[test]
#[should_panic(expected: ('Need at least 1 guardian',))]
fn test_create_inheritance_plan_zero_required_guardians() {
    let contract_address = setup();
    let dispatcher = IInheritXDispatcher { contract_address };
    let benefactor: ContractAddress = contract_address_const::<'benefactor'>();
    let beneficiary: ContractAddress = contract_address_const::<'beneficiary'>();
    let guardians: Array<ContractAddress> = array![benefactor];
    let assets: Array<AssetAllocation> = array![AssetAllocation { token: benefactor, amount: 1000, percentage: 50 }, AssetAllocation { token: beneficiary, amount: 1000, percentage: 50 }];
    
    // Ensure the caller is the admin
    cheat_caller_address(contract_address, benefactor, CheatSpan::Indefinite);
    
    // This should fail because required_guardians is 0
    dispatcher.create_inheritance_plan(1000, 0, guardians, assets);
}
