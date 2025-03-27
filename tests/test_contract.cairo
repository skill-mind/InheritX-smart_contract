#[cfg(test)]
mod tests {
    use inheritx::InheritX::InheritX;
    use inheritx::interfaces::IInheritX::{IInheritXDispatcher, IInheritXDispatcherTrait};
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
        stop_cheat_caller_address,
    };
    use starknet::{ContractAddress, contract_address_const};
    use super::*;


