
use starknet::testing::{set_caller_address, set_block_timestamp};
use core::result::ResultTrait;
use starknet::{contract_address_const, ContractAddress};
use assert_macros::assert_eq;
use snforge_std::{declare, ContractClassTrait, ContractClass, start_prank, stop_prank, start_warp, CheatTarget};
use core::traits::{Into, TryInto};
use core::integer::{u256_from_felt252, felt252_try_from_u256};

#[test]
fn test_create_bounty() {
    // Deploy the contract
    let contract = declare("BountyJob").deploy(@[]).unwrap();
    let contract_address = contract.contract_address;
    
    // Set caller address
    let recruiter = contract_address_const::<0x123>();
    start_prank(CheatTarget::One(contract_address), recruiter);
    
    // Set current time
    let current_time: u64 = 1000;
    let expiration_time: u64 = current_time + 86400; // 1 day later
    start_warp(CheatTarget::One(contract_address), current_time);
    
    // Create a bounty with 1000 tokens reward
    let reward = u256_from_felt252(1000);
    let metadata_hash = 0x456;
    let result = contract.call(
        "create_bounty", 
        @[reward.low.into(), reward.high.into(), metadata_hash.into(), expiration_time.into()]
    ).unwrap();
    
    // Check result
    let bounty_id = *result[0];
    assert(bounty_id == 1, 'Incorrect bounty ID');
    
    // Get bounty details to verify
    let details = contract.call(
        "get_bounty_details",
        @[bounty_id]
    ).unwrap();
    
    // Assert correct values were stored
    let stored_recruiter = *details[0];
    let stored_reward_low = *details[1];
    let stored_reward_high = *details[2];
    let stored_metadata = *details[3];
    let stored_status = *details[4];
    let stored_expiration = *details[5];
    
    assert(stored_recruiter.into() == recruiter.into(), 'Wrong recruiter');
    assert(stored_reward_low == reward.low.into(), 'Wrong reward low');
    assert(stored_reward_high == reward.high.into(), 'Wrong reward high');
    assert(stored_metadata == metadata_hash.into(), 'Wrong metadata hash');
    assert(stored_status == 0, 'Wrong status'); // ACTIVE = 0
    assert(stored_expiration == expiration_time.into(), 'Wrong expiration');
    
    stop_prank(CheatTarget::One(contract_address));
}

#[test]
fn test_submit_solution() {
    // Deploy the contract
    let contract = declare("BountyJob").deploy(@[]).unwrap();
    let contract_address = contract.contract_address;
    
    // Create a bounty first
    let recruiter = contract_address_const::<0x123>();
    start_prank(CheatTarget::One(contract_address), recruiter);
    
    let current_time: u64 = 1000;
    let expiration_time: u64 = current_time + 86400;
    start_warp(CheatTarget::One(contract_address), current_time);
    
    let reward = u256_from_felt252(1000);
    let metadata_hash = 0x456;
    let result = contract.call(
        "create_bounty", 
        @[reward.low.into(), reward.high.into(), metadata_hash.into(), expiration_time.into()]
    ).unwrap();
    let bounty_id = *result[0];
    
    stop_prank(CheatTarget::One(contract_address));
    
    // Now submit a solution as a different address
    let submitter = contract_address_const::<0x789>();
    start_prank(CheatTarget::One(contract_address), submitter);
    
    let solution_hash = 0xabc;
    let submission_result = contract.call(
        "submit_solution",
        @[bounty_id, solution_hash.into()]
    ).unwrap();
    
    let submission_id = *submission_result[0];
    assert(submission_id == 1, 'Incorrect submission ID');
    
    // Check submission details
    let submission = contract.call(
        "get_submission",
        @[bounty_id, submission_id]
    ).unwrap();
    
    let stored_submitter = *submission[0];
    let stored_solution_hash = *submission[1];
    
    assert(stored_submitter.into() == submitter.into(), 'Wrong submitter');
    assert(stored_solution_hash == solution_hash.into(), 'Wrong solution hash');
    
    stop_prank(CheatTarget::One(contract_address));
}

#[test]
fn test_select_winner() {
    // Deploy the contract
    let contract = declare("BountyJob").deploy(@[]).unwrap();
    let contract_address = contract.contract_address;
    
    // Create a bounty
    let recruiter = contract_address_const::<0x123>();
    start_prank(CheatTarget::One(contract_address), recruiter);
    
    let current_time: u64 = 1000;
    let expiration_time: u64 = current_time + 86400;
    start_warp(CheatTarget::One(contract_address), current_time);
    
    let reward = u256_from_felt252(1000);
    let metadata_hash = 0x456;
    let result = contract.call(
        "create_bounty", 
        @[reward.low.into(), reward.high.into(), metadata_hash.into(), expiration_time.into()]
    ).unwrap();
    let bounty_id = *result[0];
    
    stop_prank(CheatTarget::One(contract_address));
    
    // Submit a solution
    let submitter = contract_address_const::<0x789>();
    start_prank(CheatTarget::One(contract_address), submitter);
    
    let solution_hash = 0xabc;
    let submission_result = contract.call(
        "submit_solution",
        @[bounty_id, solution_hash.into()]
    ).unwrap();
    let submission_id = *submission_result[0];
    
    stop_prank(CheatTarget::One(contract_address));
    
    // Select winner as recruiter
    start_prank(CheatTarget::One(contract_address), recruiter);
    
    contract.call(
        "select_winner",
        @[bounty_id, submission_id]
    ).unwrap();
    
    // Check bounty details to verify winner was set
    let details = contract.call(
        "get_bounty_details",
        @[bounty_id]
    ).unwrap();
    
    let status = *details[4];
    let winner = *details[5];
    
    assert(status == 2, 'Wrong status'); // WINNER_SELECTED = 2
    assert(winner.into() == submitter.into(), 'Wrong winner');
    
    stop_prank(CheatTarget::One(contract_address));
}

#[test]
fn test_claim_reward() {
    // Deploy the contract
    let contract = declare("BountyJob").deploy(@[]).unwrap();
    let contract_address = contract.contract_address;
    
    // Create a bounty
    let recruiter = contract_address_const::<0x123>();
    start_prank(CheatTarget::One(contract_address), recruiter);
    
    let current_time: u64 = 1000;
    let expiration_time: u64 = current_time + 86400;
    start_warp(CheatTarget::One(contract_address), current_time);
    
    let reward = u256_from_felt252(1000);
    let metadata_hash = 0x456;
    let result = contract.call(
        "create_bounty", 
        @[reward.low.into(), reward.high.into(), metadata_hash.into(), expiration_time.into()]
    ).unwrap();
    let bounty_id = *result[0];
    
    stop_prank(CheatTarget::One(contract_address));
    
    // Submit a solution
    let submitter = contract_address_const::<0x789>();
    start_prank(CheatTarget::One(contract_address), submitter);
    
    let solution_hash = 0xabc;
    let submission_result = contract.call(
        "submit_solution",
        @[bounty_id, solution_hash.into()]
    ).unwrap();
    let submission_id = *submission_result[0];
    
    stop_prank(CheatTarget::One(contract_address));
    
    // Select winner as recruiter
    start_prank(CheatTarget::One(contract_address), recruiter);
    
    contract.call(
        "select_winner",
        @[bounty_id, submission_id]
    ).unwrap();
    
    stop_prank(CheatTarget::One(contract_address));
    
    // Claim reward as winner
    start_prank(CheatTarget::One(contract_address), submitter);
    
    contract.call(
        "claim_reward",
        @[bounty_id]
    ).unwrap();
    
    // Check bounty status
    let details = contract.call(
        "get_bounty_details",
        @[bounty_id]
    ).unwrap();
    
    let status = *details[4];
    assert(status == 3, 'Wrong status'); // COMPLETED = 3
    
    stop_prank(CheatTarget::One(contract_address));
}

#[test]
fn test_expiration() {
    // Deploy the contract
    let contract = declare("BountyJob").deploy(@[]).unwrap();
    let contract_address = contract.contract_address;
    
    // Create a bounty
    let recruiter = contract_address_const::<0x123>();
    start_prank(CheatTarget::One(contract_address), recruiter);
    
    let current_time: u64 = 1000;
    let expiration_time: u64 = current_time + 86400;
    start_warp(CheatTarget::One(contract_address), current_time);
    
    let reward = u256_from_felt252(1000);
    let metadata_hash = 0x456;
    let result = contract.call(
        "create_bounty", 
        @[reward.low.into(), reward.high.into(), metadata_hash.into(), expiration_time.into()]
    ).unwrap();
    let bounty_id = *result[0];
    
    // Check not expired initially
    let expiration_check = contract.call(
        "check_expiration",
        @[bounty_id]
    ).unwrap();
    let is_expired = *expiration_check[0];
    assert(is_expired == 0, 'Should not be expired');
    
    // Warp time past expiration
    start_warp(CheatTarget::One(contract_address), expiration_time + 1);
    
    // Check expired after time passed
    let expiration_check = contract.call(
        "check_expiration",
        @[bounty_id]
    ).unwrap();
    let is_expired = *expiration_check[0];
    assert(is_expired == 1, 'Should be expired');
    
    // Verify status change
    let details = contract.call(
        "get_bounty_details",
        @[bounty_id]
    ).unwrap();
    let status = *details[4];
    assert(status == 1, 'Wrong status'); // EXPIRED = 1
    
    stop_prank(CheatTarget::One(contract_address));
}

#[test]
#[should_panic(expected: ('Bounty has expired',))]
fn test_cannot_submit_to_expired_bounty() {
    // Deploy the contract
    let contract = declare("BountyJob").deploy(@[]).unwrap();
    let contract_address = contract.contract_address;
    
    // Create a bounty
    let recruiter = contract_address_const::<0x123>();
    start_prank(CheatTarget::One(contract_address), recruiter);
    
    let current_time: u64 = 1000;
    let expiration_time: u64 = current_time + 86400;
    start_warp(CheatTarget::One(contract_address), current_time);
    
    let reward = u256_from_felt252(1000);
    let metadata_hash = 0x456;
    let result = contract.call(
        "create_bounty", 
        @[reward.low.into(), reward.high.into(), metadata_hash.into(), expiration_time.into()]
    ).unwrap();
    let bounty_id = *result[0];
    
    // Warp time past expiration
    start_warp(CheatTarget::One(contract_address), expiration_time + 1);
    
    // Try to submit after expiration - should fail
    let submitter = contract_address_const::<0x789>();
    start_prank(CheatTarget::One(contract_address), submitter);
    
    let solution_hash = 0xabc;
    contract.call(
        "submit_solution",
        @[bounty_id, solution_hash.into()]
    ).unwrap();
}
