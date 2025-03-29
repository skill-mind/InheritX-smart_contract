use array::ArrayTrait;
use core::traits::Into;
use inheritx::enums::PlanStatus;
use inheritx::interfaces::IInheritXPlan::{IInheritXPlanDispatcher, IInheritXPlanDispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare, storage_read,
    storage_write,
};
use starknet::{ContractAddress, contract_address_const};

fn setup() -> IInheritXPlanDispatcher {
    let contract_class = declare("InheritxPlan").unwrap().contract_class();
    let calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IInheritXPlanDispatcher { contract_address }
}

#[test]
fn test_override_plan_real_logic() {
    let dispatcher = setup();
    let contract_address = dispatcher.contract_address;

    let plan_id = 0;
    let owner: ContractAddress = contract_address_const::<'owner'>();

    cheat_caller_address(contract_address, owner, CheatSpan::Indefinite);

    storage_write(contract_address, "InheritxPlan::Storage::plans_count", array![], 1);
    storage_write(
        contract_address, "InheritxPlan::Storage::plan_asset_owner", array![plan_id], owner,
    );
    storage_write(
        contract_address,
        "InheritxPlan::Storage::plan_status",
        array![plan_id],
        PlanStatus::Active.into(),
    );

    dispatcher.override_plan(plan_id);

    let result = storage_read::<
        u8,
    >(contract_address, "InheritxPlan::Storage::plan_status", array![plan_id]);
    assert(result == PlanStatus::Cancelled.into(), 'Expected plan to be Cancelled');
}

#[test]
#[should_panic(expected: 'Plan ID does not exist')]
fn test_override_plan_invalid_plan_id() {
    let dispatcher = setup();
    let contract_address = dispatcher.contract_address;

    let plan_id = 0;
    let owner: ContractAddress = contract_address_const::<'owner'>();

    cheat_caller_address(contract_address, owner, CheatSpan::Indefinite);

    storage_write(
        contract_address, "InheritxPlan::Storage::plans_count", array![], 0,
    ); // ningún plan

    dispatcher.override_plan(plan_id);
}

#[test]
#[should_panic(expected: 'Not plan owner')]
fn test_override_plan_wrong_owner() {
    let dispatcher = setup();
    let contract_address = dispatcher.contract_address;

    let plan_id = 0;
    let actual_owner: ContractAddress = contract_address_const::<'owner'>();
    let caller: ContractAddress = contract_address_const::<'not_owner'>();

    cheat_caller_address(contract_address, caller, CheatSpan::Indefinite);

    storage_write(contract_address, "InheritxPlan::Storage::plans_count", array![], 1);
    storage_write(
        contract_address, "InheritxPlan::Storage::plan_asset_owner", array![plan_id], actual_owner,
    );
    storage_write(
        contract_address,
        "InheritxPlan::Storage::plan_status",
        array![plan_id],
        PlanStatus::Active.into(),
    );

    dispatcher.override_plan(plan_id);
}

#[test]
#[should_panic(expected: 'Already executed')]
fn test_override_plan_already_executed() {
    let dispatcher = setup();
    let contract_address = dispatcher.contract_address;

    let plan_id = 0;
    let owner: ContractAddress = contract_address_const::<'owner'>();

    cheat_caller_address(contract_address, owner, CheatSpan::Indefinite);

    storage_write(contract_address, "InheritxPlan::Storage::plans_count", array![], 1);
    storage_write(
        contract_address, "InheritxPlan::Storage::plan_asset_owner", array![plan_id], owner,
    );
    storage_write(
        contract_address,
        "InheritxPlan::Storage::plan_status",
        array![plan_id],
        PlanStatus::Executed.into(),
    );

    dispatcher.override_plan(plan_id);
}

#[test]
#[should_panic(expected: 'Cannot override plan')]
fn test_override_plan_cannot_override_logic() {
    let dispatcher = setup();
    let contract_address = dispatcher.contract_address;

    let plan_id = 0;
    let owner: ContractAddress = contract_address_const::<'owner'>();

    cheat_caller_address(contract_address, owner, CheatSpan::Indefinite);

    storage_write(contract_address, "InheritxPlan::Storage::plans_count", array![], 1);
    storage_write(
        contract_address, "InheritxPlan::Storage::plan_asset_owner", array![plan_id], owner,
    );
    storage_write(
        contract_address,
        "InheritxPlan::Storage::plan_status",
        array![plan_id],
        PlanStatus::Draft.into(),
    );

    dispatcher.override_plan(plan_id);
}

