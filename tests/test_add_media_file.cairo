#[test]
fn test_add_media_file_to_plan_valid() {
    // Setup
    let mut contract = ContractState::default();
    let plan_id = 1_u256;
    let media_file = MediaMessage {
        file_hash: 0xabc,
        file_name: 0x123,
        file_type: 0x1, // Example: 1 for image
        file_size: 1024,
        recipients_count: 1,
        upload_date: 1234567890,
    };
    let recipient = ContractAddress::from(0x456);

    // Initialize state
    contract.plans_id.write(plan_id);
    contract.plan_media_messages_count.write(plan_id, 0);

    // Call function
    contract.add_media_file_to_plan(plan_id, media_file, recipient);

    // Assertions
    assert(contract.plan_media_messages_count.read(plan_id) == 1, 'Media message count mismatch');
    assert(contract.plan_media_messages.read((plan_id, 1)) == media_file, 'Media file not stored correctly');
    assert(
        contract.media_message_recipients.read((plan_id, 1, 1)) == recipient,
        'Recipient not stored correctly'
    );
}

#[test]
fn test_add_media_file_to_plan_invalid_plan_id() {
    // Setup
    let mut contract = ContractState::default();
    let plan_id = 2_u256; // Invalid plan ID
    let media_file = MediaMessage {
        file_hash: 0xabc,
        file_name: 0x123,
        file_type: 0x1,
        file_size: 1024,
        recipients_count: 1,
        upload_date: 1234567890,
    };
    let recipient = ContractAddress::from(0x456);

    // Initialize state
    contract.plans_id.write(1_u256); // Only plan ID 1 exists

    // Call function and expect failure
    assert_panics(|| {
        contract.add_media_file_to_plan(plan_id, media_file, recipient);
    }, 'Invalid plan id');
}

#[test]
fn test_add_media_file_to_plan_no_recipients() {
    // Setup
    let mut contract = ContractState::default();
    let plan_id = 1_u256;
    let media_file = MediaMessage {
        file_hash: 0xabc,
        file_name: 0x123,
        file_type: 0x1,
        file_size: 1024,
        recipients_count: 0, // No recipients
        upload_date: 1234567890,
    };
    let recipient = ContractAddress::from(0x456);

    // Initialize state
    contract.plans_id.write(plan_id);

    // Call function and expect failure
    assert_panics(|| {
        contract.add_media_file_to_plan(plan_id, media_file, recipient);
    }, 'Invalid recipient count');
}

#[test]
fn test_add_media_file_to_plan_multiple_calls() {
    // Setup
    let mut contract = ContractState::default();
    let plan_id = 1_u256;
    let media_file_1 = MediaMessage {
        file_hash: 0xabc,
        file_name: 0x123,
        file_type: 0x1,
        file_size: 1024,
        recipients_count: 1,
        upload_date: 1234567890,
    };
    let media_file_2 = MediaMessage {
        file_hash: 0xdef,
        file_name: 0x456,
        file_type: 0x2, // Example: 2 for video
        file_size: 2048,
        recipients_count: 1,
        upload_date: 1234567891,
    };
    let recipient_1 = ContractAddress::from(0x456);
    let recipient_2 = ContractAddress::from(0x789);

    // Initialize state
    contract.plans_id.write(plan_id);
    contract.plan_media_messages_count.write(plan_id, 0);

    // Call function twice
    contract.add_media_file_to_plan(plan_id, media_file_1, recipient_1);
    contract.add_media_file_to_plan(plan_id, media_file_2, recipient_2);

    // Assertions
    assert(contract.plan_media_messages_count.read(plan_id) == 2, 'Media message count mismatch');
    assert(contract.plan_media_messages.read((plan_id, 1)) == media_file_1, 'Media file 1 not stored correctly');
    assert(contract.plan_media_messages.read((plan_id, 2)) == media_file_2, 'Media file 2 not stored correctly');
    assert(
        contract.media_message_recipients.read((plan_id, 1, 1)) == recipient_1,
        'Recipient 1 not stored correctly'
    );
    assert(
        contract.media_message_recipients.read((plan_id, 2, 1)) == recipient_2,
        'Recipient 2 not stored correctly'
    );
}

#[test]
fn test_add_media_file_to_plan_large_file() {
    // Setup
    let mut contract = ContractState::default();
    let plan_id = 1_u256;
    let media_file = MediaMessage {
        file_hash: 0xabc,
        file_name: 0x123,
        file_type: 0x1,
        file_size: 10_000_000, // Large file size
        recipients_count: 1,
        upload_date: 1234567890,
    };
    let recipient = ContractAddress::from(0x456);

    // Initialize state
    contract.plans_id.write(plan_id);
    contract.plan_media_messages_count.write(plan_id, 0);

    // Call function
    contract.add_media_file_to_plan(plan_id, media_file, recipient);

    // Assertions
    assert(contract.plan_media_messages_count.read(plan_id) == 1, 'Media message count mismatch');
    assert(contract.plan_media_messages.read((plan_id, 1)) == media_file, 'Large media file not stored correctly');
    assert(
        contract.media_message_recipients.read((plan_id, 1, 1)) == recipient,
        'Recipient not stored correctly for large file'
    );
}