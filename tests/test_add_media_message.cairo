import pytest
from starkware.starknet.testing.starknet import Starknet

@pytest.mark.asyncio
async def test_add_media_message():
    # Deploy the contract
    starknet = await Starknet.empty()
    contract = await starknet.deploy("contracts/InheritX.cairo")

    # Add a media message to a plan
    plan_id = 1
    media_type = 0  # Example: 0 for image
    media_content = 123456  # Example: IPFS hash or URL as felt
    await contract.add_media_message(plan_id, media_type, media_content).invoke()

    # Verify the media message was added
    execution_info = await contract.media_messages(plan_id).call()
    messages = execution_info.result.messages

    assert len(messages) == 1
    assert messages[0].plan_id == plan_id
    assert messages[0].media_type == media_type
    assert messages[0].media_content == media_content