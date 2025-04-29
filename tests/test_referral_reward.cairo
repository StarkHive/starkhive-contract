// Tests for ReferralReward contract

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_block_timestamp
from contracts.ReferralReward import ReferralReward
from contracts.JobAgreement import JobAgreement
use snforge_std::{mock_call, MockCallResult};

// Mock constants
const OWNER = 0x123;
const REFERRER = 0x456;
const REFEREE = 0x789;
const OTHER_USER = 0xabc;
const TOKEN_ADDRESS = 0xdef;
const REWARD_AMOUNT_LOW = 100000000000000000; // 0.1 tokens with 18 decimals
const REWARD_AMOUNT_HIGH = 0;
const COOLDOWN_PERIOD = 86400; // 1 day in seconds

@contract_interface
namespace IToken:
    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end
    func balanceOf(account: felt) -> (balance: Uint256):
    end
end

@contract_interface
namespace IReferralReward:
    func create_referral(referrer: felt, referee: felt) -> (success: felt):
    end
    func process_job_completion(job_id: felt) -> (success: felt):
    end
    func update_reward_config(token_address: felt, reward_amount_: Uint256):
    end
    func update_cooldown(new_cooldown: felt):
    end
    func get_referrer(referee: felt) -> (referrer: felt):
    end
    func check_user_completed_job(user: felt) -> (completed: felt):
    end
    func get_reward_config() -> (token: felt, amount: Uint256):
    end
    func get_cooldown_period() -> (seconds: felt):
    end
    func get_time_until_next_referral(user: felt) -> (seconds: felt):
    end
end

// Test referral creation
@test
func test_create_referral():
    // Deploy contracts
    let job_agreement = JobAgreement.deploy()
    
    let reward_amount = Uint256(REWARD_AMOUNT_LOW, REWARD_AMOUNT_HIGH)
    let referral_reward = ReferralReward.deploy(
        OWNER, job_agreement.contract_address, TOKEN_ADDRESS, reward_amount, COOLDOWN_PERIOD
    )
    
    // Create a referral
    let (success) = referral_reward.create_referral(REFERRER, REFEREE)
    assert success = 1
    
    // Check referrer is set correctly
    let (referrer) = referral_reward.get_referrer(REFEREE)
    assert referrer = REFERRER
    
    return ()
end

// Test self-referral prevention
@test
func test_prevent_self_referral():
    // Deploy contracts
    let job_agreement = JobAgreement.deploy()
    
    let reward_amount = Uint256(REWARD_AMOUNT_LOW, REWARD_AMOUNT_HIGH)
    let referral_reward = ReferralReward.deploy(
        OWNER, job_agreement.contract_address, TOKEN_ADDRESS, reward_amount, COOLDOWN_PERIOD
    )
    
    // Try to create a self-referral
    %{ expect_revert("Cannot refer yourself") %}
    let (success) = referral_reward.create_referral(REFERRER, REFERRER)
    
    return ()
end

// Test duplicate referral prevention
@test
func test_prevent_duplicate_referral():
    // Deploy contracts
    let job_agreement = JobAgreement.deploy()
    
    let reward_amount = Uint256(REWARD_AMOUNT_LOW, REWARD_AMOUNT_HIGH)
    let referral_reward = ReferralReward.deploy(
        OWNER, job_agreement.contract_address, TOKEN_ADDRESS, reward_amount, COOLDOWN_PERIOD
    )
    
    // Create a referral
    let (success1) = referral_reward.create_referral(REFERRER, REFEREE)
    assert success1 = 1
    
    // Try to create a duplicate referral with different referrer
    %{ expect_revert("Referee already has a referrer") %}
    let (success2) = referral_reward.create_referral(OTHER_USER, REFEREE)
    
    return ()
end

// Test cooldown period
@test
func test_cooldown_period():
    // Deploy contracts
    let job_agreement = JobAgreement.deploy()
    
    let reward_amount = Uint256(REWARD_AMOUNT_LOW, REWARD_AMOUNT_HIGH)
    let referral_reward = ReferralReward.deploy(
        OWNER, job_agreement.contract_address, TOKEN_ADDRESS, reward_amount, COOLDOWN_PERIOD
    )
    
    // Create a referral
    let (success1) = referral_reward.create_referral(REFERRER, REFEREE)
    assert success1 = 1
    
    // Try to create another referral immediately
    %{ expect_revert("Cooldown period not elapsed") %}
    let (success2) = referral_reward.create_referral(REFERRER, OTHER_USER)
    
    // Check time until next referral
    let (time_left) = referral_reward.get_time_until_next_referral(REFERRER)
    assert time_left > 0
    
    // Advance time beyond cooldown
    %{ stop_prank_callable = start_prank(caller_address=REFERRER) %}
    %{ warp(86401) %} // 1 day + 1 second
    
    // Check time again - should be zero
    let (time_left2) = referral_reward.get_time_until_next_referral(REFERRER)
    assert time_left2 = 0
    
    // Now we should be able to create another referral
    let (success3) = referral_reward.create_referral(REFERRER, OTHER_USER)
    assert success3 = 1
    
    %{ stop_prank_callable() %}
    
    return ()
end

// Test job completion and rewards
@test
func test_process_job_completion():
    // Deploy contracts
    let job_agreement = JobAgreement.deploy()
    
    let reward_amount = Uint256(REWARD_AMOUNT_LOW, REWARD_AMOUNT_HIGH)
    let referral_reward = ReferralReward.deploy(
        OWNER, job_agreement.contract_address, TOKEN_ADDRESS, reward_amount, COOLDOWN_PERIOD
    )
    
    // Create a job for the referee
    %{ stop_prank_callable = start_prank(caller_address=OWNER) %}
    let (job_id) = job_agreement.propose_job(OWNER, REFEREE, 0x123)
    
    // Create a referral
    let (success) = referral_reward.create_referral(REFERRER, REFEREE)
    assert success = 1
    
    // Move job to active state
    %{ stop_prank_callable() %}
    %{ stop_prank_callable2 = start_prank(caller_address=REFEREE) %}
    job_agreement.accept_job(job_id)
    %{ stop_prank_callable2() %}
    
    %{ stop_prank_callable3 = start_prank(caller_address=OWNER) %}
    job_agreement.activate_job(job_id)
    
    // Complete the job
    job_agreement.complete_job(job_id)
    
    // Mock token transfer to succeed
    mock_call(TOKEN_ADDRESS, selector!("transfer"), MockCallResult::Return(array![1_u32]));
    
    // Process job completion to award referral
    let (completion_success) = referral_reward.process_job_completion(job_id)
    assert completion_success = 1
    
    // Verify that freelancer is marked as having completed a job
    let (has_completed) = referral_reward.check_user_completed_job(REFEREE)
    assert has_completed = 1
    
    // Try processing again - should not error but no new reward
    let (completion_success2) = referral_reward.process_job_completion(job_id)
    assert completion_success2 = 1
    
    %{ stop_prank_callable3() %}
    
    return ()
end

// Test reward configuration update
@test
func test_update_reward_config():
    // Deploy contracts
    let job_agreement = JobAgreement.deploy()
    
    let reward_amount = Uint256(REWARD_AMOUNT_LOW, REWARD_AMOUNT_HIGH)
    let referral_reward = ReferralReward.deploy(
        OWNER, job_agreement.contract_address, TOKEN_ADDRESS, reward_amount, COOLDOWN_PERIOD
    )
    
    // Check initial config
    let (token, amount) = referral_reward.get_reward_config()
    assert token = TOKEN_ADDRESS
    assert amount.low = REWARD_AMOUNT_LOW
    assert amount.high = REWARD_AMOUNT_HIGH
    
    // Update reward config
    %{ stop_prank_callable = start_prank(caller_address=OWNER) %}
    let new_token = 0xaaa
    let new_amount = Uint256(200000000000000000, 0) // 0.2 tokens
    referral_reward.update_reward_config(new_token, new_amount)
    %{ stop_prank_callable() %}
    
    // Check updated config
    let (token2, amount2) = referral_reward.get_reward_config()
    assert token2 = new_token
    assert amount2.low = new_amount.low
    assert amount2.high = new_amount.high
    
    return ()
end

// Test cooldown update
@test
func test_update_cooldown():
    // Deploy contracts
    let job_agreement = JobAgreement.deploy()
    
    let reward_amount = Uint256(REWARD_AMOUNT_LOW, REWARD_AMOUNT_HIGH)
    let referral_reward = ReferralReward.deploy(
        OWNER, job_agreement.contract_address, TOKEN_ADDRESS, reward_amount, COOLDOWN_PERIOD
    )
    
    // Check initial cooldown
    let (cooldown) = referral_reward.get_cooldown_period()
    assert cooldown = COOLDOWN_PERIOD
    
    // Update cooldown
    %{ stop_prank_callable = start_prank(caller_address=OWNER) %}
    let new_cooldown = 3600 // 1 hour
    referral_reward.update_cooldown(new_cooldown)
    %{ stop_prank_callable() %}
    
    // Check updated cooldown
    let (cooldown2) = referral_reward.get_cooldown_period()
    assert cooldown2 = new_cooldown
    
    return ()
end 