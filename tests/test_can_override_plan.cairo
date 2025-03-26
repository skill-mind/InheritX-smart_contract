#[cfg(test)]
mod tests {
    use inheritx::interfaces::IInheritXPlan::{IInheritXPlanDispatcher, IInheritXPlanDispatcherTrait};
    use snforge_std::{
        ContractClassTrait, 
        DeclareResultTrait, 
        declare, 
        start_cheat_caller_address, 
        stop_cheat_caller_address,
        start_cheat_block_timestamp, 
        stop_cheat_block_timestamp
    };
    use starknet::{ContractAddress, contract_address_const};

    const PLAN_ID: u256 = 0_u256;
    const CREATION_DATE: u64 = 1000_u64;
    const LOCK_PERIOD: u64 = 86400; // 24 hours in seconds

    fn set_up() -> IInheritXPlanDispatcher {
        // Declare and deploy InheritXPlan contract
        let inheritx_plan_class = declare("InheritxPlan").unwrap().contract_class();
        let (inheritx_plan_address, _) = inheritx_plan_class.deploy(@array![]).unwrap();
        let inheritx_plan_dispatcher = IInheritXPlanDispatcher { contract_address: inheritx_plan_address };

        inheritx_plan_dispatcher
    }

    #[test]
    fn test_can_override_plan_not_owner() {
        let inheritx_plan_dispatcher = set_up();
        
        let non_owner = contract_address_const::<'other'>();
        
        // Execute test as non-owner
        start_cheat_caller_address(inheritx_plan_dispatcher.contract_address, non_owner);
        let can_override = inheritx_plan_dispatcher.can_override_plan(PLAN_ID);
        stop_cheat_caller_address(inheritx_plan_dispatcher.contract_address);
        
        // Verify results
        assert(!can_override, 'Non-owner cannot override');
    }

    #[test]
    fn test_can_override_plan_within_lock_period() {
        let inheritx_plan_dispatcher = set_up();
        
        let owner = contract_address_const::<'owner'>();
        
        // Setup as the owner
        start_cheat_caller_address(inheritx_plan_dispatcher.contract_address, owner);
        start_cheat_block_timestamp(inheritx_plan_dispatcher.contract_address, CREATION_DATE + LOCK_PERIOD - 1);
        
        let can_override = inheritx_plan_dispatcher.can_override_plan(PLAN_ID);
        
        stop_cheat_block_timestamp(inheritx_plan_dispatcher.contract_address);
        stop_cheat_caller_address(inheritx_plan_dispatcher.contract_address);
        
        assert(!can_override, 'Plan in lock period');
    }

    #[test]
    fn test_can_override_plan_after_lock_period() {
        let inheritx_plan_dispatcher = set_up();
        
        let owner = contract_address_const::<'owner'>();
        
        // Setup as the owner
        start_cheat_caller_address(inheritx_plan_dispatcher.contract_address, owner);
        start_cheat_block_timestamp(inheritx_plan_dispatcher.contract_address, CREATION_DATE + LOCK_PERIOD + 1);
        
        let can_override = inheritx_plan_dispatcher.can_override_plan(PLAN_ID);
        
        stop_cheat_block_timestamp(inheritx_plan_dispatcher.contract_address);
        stop_cheat_caller_address(inheritx_plan_dispatcher.contract_address);
        
        assert(can_override, 'Plan after lock period');
    }

    #[test]
    fn test_can_override_plan_already_executed() {
        let inheritx_plan_dispatcher = set_up();
        
        let owner = contract_address_const::<'owner'>();
        
        // Prepare plan storage
        start_cheat_caller_address(inheritx_plan_dispatcher.contract_address, owner);
        
        let can_override = inheritx_plan_dispatcher.can_override_plan(PLAN_ID);
        
        stop_cheat_caller_address(inheritx_plan_dispatcher.contract_address);
        
        // Verify results
        assert(!can_override, 'Executed plan cannot override');
    }
}