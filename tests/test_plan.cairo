// Import the contract modules
use inheritx::imple::InheritXClaim::InheritxClaim;
use inheritx::imple::InheritXPlan::InheritxPlan;
use inheritx::interfaces::IInheritXPlan::{
    IInheritXPlan, IInheritXPlanDispatcher, IInheritXPlanDispatcherTrait, PlanConditions,
    SimpleBeneficiary, TokenInfo,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use starknet::class_hash::ClassHash;
use starknet::contract_address::contract_address_const;
use starknet::testing::{set_caller_address, set_contract_address};
// Test function to set up contracts


