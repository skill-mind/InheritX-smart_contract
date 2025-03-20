use starknet::ContractAddress;
use starknet::testing::{set_caller_address, set_contract_address};
use starknet::class_hash::ClassHash;
use starknet::contract_address::contract_address_const;
// Import the contract modules
use inheritx::imple::InheritXClaim::InheritxClaim;
use inheritx::imple::InheritXPlan::InheritxPlan;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};


use inheritx::interfaces::IInheritXClaim::{
    IInheritXClaim, IInheritXClaimDispatcher, IInheritXClaimDispatcherTrait,
};


