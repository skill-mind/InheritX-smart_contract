
use inheritx::interfaces::IInheritX::{IInheritXDispatcher, IInheritXDispatcherTrait};
use snforge_std::{
    declare, 
    ContractClassTrait, 
    DeclareResultTrait, 
    store, 
    map_entry_address, 
};

fn setup() -> IInheritXDispatcher {
    let contract_class = declare("InheritX").unwrap().contract_class();
    let mut calldata = array![];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IInheritXDispatcher { contract_address }
}

#[test]
fn test_get_media_preview_url_success() {
    let inheritX = setup();
    
    // Set plans_count (u256 needs 2 felts: low, high)
    store(
        inheritX.contract_address, 
        selector!("plans_count"), 
        array![1, 0].span() // u256(1) = (low: 1, high: 0)
    );
    
    let plan_id: u256 = 0;
    let file_hash: felt252 = 'test_file_hash';
    let preview_url: felt252 = 'http://example.com/preview';
    
    // Serialize u256 as two felts (low, high)
    let (low, high) = (0, 0); // Since plan_id = 0
    
    let keys = array![
        low,    // u256 low part
        high,   // u256 high part
        file_hash
    ];
    
    store(
        inheritX.contract_address,
        map_entry_address(selector!("plan_media_preview_urls"), keys.span()),
        array![preview_url].span()
    );
    
    let retrieved_url = inheritX.get_media_preview_url(plan_id, file_hash);
    assert(retrieved_url == preview_url, 'Incorrect preview URL');
}

#[test]
#[should_panic(expected: 'Plan does not exist' )]
fn test_get_media_preview_url_invalid_plan_id() {
    let inheritX = setup();
    
    let invalid_plan_id: u256 = 999;
    let file_hash: felt252 = 'test_file_hash';
    
    inheritX.get_media_preview_url(invalid_plan_id, file_hash);
}

#[test]
#[should_panic(expected: 'Invalid file hash' )]
fn test_get_media_preview_url_zero_file_hash() {
    let inheritX = setup();
    
    // Set plans_count
    store(
        inheritX.contract_address, 
        selector!("plans_count"), 
        array![1].span()
    );
    
    let plan_id: u256 = 0;
    let zero_file_hash: felt252 = 0;
    
    inheritX.get_media_preview_url(plan_id, zero_file_hash);
}

#[test]
#[should_panic(expected: 'File not found in plan' )]
fn test_get_media_preview_url_nonexistent_file() {
    let inheritX = setup();
    
    // Set plans_count
    store(
        inheritX.contract_address, 
        selector!("plans_count"), 
        array![1].span()
    );
    
    let plan_id: u256 = 0;
    let nonexistent_file_hash: felt252 = 'nonexistent_hash';
    
    inheritX.get_media_preview_url(plan_id, nonexistent_file_hash);
}