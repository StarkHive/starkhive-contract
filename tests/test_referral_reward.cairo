%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.starknet.common.syscalls import emit_event

// Import the contract we want to test
from src.ReferralReward import (
    constructor,
    register_referral,
    complete_job,
    get_referrer,
    has_completed_job, 
    set_token_contract,
    get_token_contract,
    transfer_ownership,
    get_owner
)

// Constants for testing
const OWNER = 0x123;
const REFERRER = 0x456;
const REFEREE = 0x789;
const OTHER_USER = 0xabc;
const TOKEN_ADDRESS = 0xdef;

// Mock token contract
@contract_interface
namespace MockERC20 {
    func transfer(recipient: felt, amount_low: felt, amount_high: felt) -> (success: felt) {
    }
}

@external
func __setup__() {
    // This function is called before each test
    // Initialize contract
    %{ context.owner = ids.OWNER %}
    %{ context.referrer = ids.REFERRER %}
    %{ context.referee = ids.REFEREE %}
    %{ context.other_user = ids.OTHER_USER %}
    %{ context.token_address = ids.TOKEN_ADDRESS %}
    
    // Deploy the contract
    %{
        context.contract_address = deploy_contract("src/ReferralReward.cairo", [context.owner, context.token_address]).contract_address
    %}
    
    return ();
}

@external
func test_constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    
    // Call get_owner and verify it's set correctly
    %{ stop_prank_callable = start_prank(context.owner, context.contract_address) %}
    let (owner_address) = get_owner();
    assert owner_address = OWNER;
    
    // Call get_token_contract and verify it's set correctly
    let (token_address) = get_token_contract();
    assert token_address = TOKEN_ADDRESS;
    
    %{ stop_prank_callable() %}
    return ();
}

@external
func test_register_referral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    
    // Set caller as referee
    %{ stop_prank_callable = start_prank(context.referee, context.contract_address) %}
    
    // Register referral
    let (success) = register_referral(REFERRER);
    assert success = 1;
    
    // Check referral relationship
    let (referrer) = get_referrer(REFEREE);
    assert referrer = REFERRER;
    
    %{ stop_prank_callable() %}
    return ();
}

@external
func test_prevent_self_referral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    
    // Set caller as referee
    %{ stop_prank_callable = start_prank(context.referee, context.contract_address) %}
    
    // Try to refer yourself (should fail)
    %{ expect_revert(error_message="Cannot refer yourself") %}
    let (success) = register_referral(REFEREE);
    
    %{ stop_prank_callable() %}
    return ();
}

@external
func test_already_referred{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    
    // Set caller as referee
    %{ stop_prank_callable = start_prank(context.referee, context.contract_address) %}
    
    // Register first referral
    let (success) = register_referral(REFERRER);
    assert success = 1;
    
    // Try to register another referral (should fail)
    %{ expect_revert(error_message="Already referred") %}
    let (success2) = register_referral(OTHER_USER);
    
    %{ stop_prank_callable() %}
    return ();
}

@external
func test_complete_job{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    
    // First register a referral
    %{ stop_prank_callable = start_prank(context.referee, context.contract_address) %}
    let (success1) = register_referral(REFERRER);
    %{ stop_prank_callable() %}
    
    // Only owner can complete job
    %{ stop_prank_callable = start_prank(context.owner, context.contract_address) %}
    
    // Mock the token transfer to return success
    %{
        store_mock_callable = mock_call(
            context.token_address, "transfer", 
            [1]  # Return value: success = 1
        )
    %}
    
    // Complete the job
    let (success2) = complete_job(REFEREE);
    assert success2 = 1;
    
    // Check job completion status
    let (completed) = has_completed_job(REFEREE);
    assert completed = 1;
    
    %{ stop_prank_callable() %}
    %{ store_mock_callable() %}
    return ();
}

@external
func test_unauthorized_complete_job{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    
    // Non-owner tries to complete job
    %{ stop_prank_callable = start_prank(context.other_user, context.contract_address) %}
    
    // Should fail due to authorization
    %{ expect_revert(error_message="Not authorized") %}
    let (success) = complete_job(REFEREE);
    
    %{ stop_prank_callable() %}
    return ();
}

@external
func test_cooldown_period{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    
    // Register two referees with the same referrer
    %{ stop_prank_callable = start_prank(context.referee, context.contract_address) %}
    let (success1) = register_referral(REFERRER);
    %{ stop_prank_callable() %}
    
    %{ stop_prank_callable = start_prank(context.other_user, context.contract_address) %}
    let (success2) = register_referral(REFERRER);
    %{ stop_prank_callable() %}
    
    // Mock the token transfer to return success
    %{
        store_mock_callable = mock_call(
            context.token_address, "transfer", 
            [1]  # Return value: success = 1
        )
    %}
    
    // Owner completes job for first referee
    %{ stop_prank_callable = start_prank(context.owner, context.contract_address) %}
    let (success3) = complete_job(REFEREE);
    
    // Complete job for second referee (should not trigger reward due to cooldown)
    let (success4) = complete_job(OTHER_USER);
    %{ stop_prank_callable() %}
    
    %{ store_mock_callable() %}
    return ();
}

@external
func test_transfer_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    
    // Owner transfers ownership
    %{ stop_prank_callable = start_prank(context.owner, context.contract_address) %}
    transfer_ownership(OTHER_USER);
    
    // Check new owner
    let (new_owner) = get_owner();
    assert new_owner = OTHER_USER;
    
    %{ stop_prank_callable() %}
    return ();
}

@external
func test_unauthorized_transfer_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    
    // Non-owner tries to transfer ownership
    %{ stop_prank_callable = start_prank(context.other_user, context.contract_address) %}
    
    // Should fail
    %{ expect_revert(error_message="Not owner") %}
    transfer_ownership(REFEREE);
    
    %{ stop_prank_callable() %}
    return ();
}

@external
func test_set_token_contract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    
    // Owner sets new token contract
    %{ stop_prank_callable = start_prank(context.owner, context.contract_address) %}
    
    const NEW_TOKEN = 0x111;
    set_token_contract(NEW_TOKEN);
    
    // Check token contract
    let (token_address) = get_token_contract();
    assert token_address = NEW_TOKEN;
    
    %{ stop_prank_callable() %}
    return ();
}

@external
func test_unauthorized_set_token_contract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    
    // Non-owner tries to set token contract
    %{ stop_prank_callable = start_prank(context.other_user, context.contract_address) %}
    
    // Should fail
    %{ expect_revert(error_message="Not owner") %}
    set_token_contract(0x111);
    
    %{ stop_prank_callable() %}
    return ();
} 