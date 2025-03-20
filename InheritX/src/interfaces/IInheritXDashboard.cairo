use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
struct DashboardStats {
    total_value: u256,
    active_plans: u32,
    beneficiary_count: u32,
    last_updated: u64,
}

#[derive(Copy, Drop, Serde)]
struct Activity {
    timestamp: u64,
    activity_type: ActivityType,
    details: felt252,
    related_id: u256,
    actor: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
enum ActivityType {
    PlanCreation: (),
    PlanModification: (),
    AssetSwap: (),
    BeneficiaryAdded: (),
    GuardianAction: (),
    ClaimInitiated: (),
    ClaimApproved: (),
    EmergencyAction: (),
}

#[starknet::interface]
trait IInheritXDashboard<TContractState> {
    // Dashboard Statistics
    fn get_dashboard_stats(self: @TContractState, user: ContractAddress) -> DashboardStats;
    fn get_total_asset_value(self: @TContractState, user: ContractAddress) -> u256;
    fn get_active_plans_count(self: @TContractState, user: ContractAddress) -> u32;
    fn get_beneficiary_count(self: @TContractState, user: ContractAddress) -> u32;

    // Recent Activities
    fn get_recent_activities(
        self: @TContractState, user: ContractAddress, page: u32, limit: u32,
    ) -> Array<Activity>;

    fn get_activity_details(self: @TContractState, activity_id: u256) -> Activity;

    // Quick Actions Status
    fn can_create_plan(self: @TContractState, user: ContractAddress) -> bool;
    fn can_swap_assets(self: @TContractState, user: ContractAddress) -> bool;
    fn has_pending_actions(self: @TContractState, user: ContractAddress) -> bool;

    // User Specific Views
    fn get_user_role(self: @TContractState, user: ContractAddress) -> felt252;
    fn get_connected_wallets(
        self: @TContractState, user: ContractAddress,
    ) -> Array<ContractAddress>;
    fn get_notification_settings(self: @TContractState, user: ContractAddress) -> felt252;

    // Dashboard Settings
    fn update_notification_settings(
        ref self: TContractState, user: ContractAddress, settings: felt252,
    );

    fn set_default_view(ref self: TContractState, user: ContractAddress, view_type: felt252);

    // Activity Tracking
    fn record_dashboard_activity(
        ref self: TContractState,
        user: ContractAddress,
        activity_type: ActivityType,
        details: felt252,
        related_id: u256,
    );

    // Analytics
    fn get_asset_distribution(
        self: @TContractState, user: ContractAddress,
    ) -> Array<(ContractAddress, u256)>;
    fn get_plan_statistics(
        self: @TContractState, user: ContractAddress,
    ) -> (u32, u32, u32); // (total_plans, active_plans, completed_plans)
}

