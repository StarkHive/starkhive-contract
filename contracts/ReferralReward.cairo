// SPDX-License-Identifier: MIT
// Referral Reward contract for StarkHive

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.bool import TRUE, FALSE

// Interface for ERC20 tokens (reward token)
@contract_interface
namespace IERC20:
    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end
    func balanceOf(account: felt) -> (balance: Uint256):
    end
end

// Interface for JobAgreement contract
@contract_interface
namespace IJobAgreement:
    func job_state(job_id: felt) -> (state: felt):
    end
    func freelancer_of(job_id: felt) -> (freelancer: felt):
    end
end

// Storage variables
@storage_var
func referrals(referee: felt) -> (referrer: felt):
end

@storage_var
func has_completed_job(user: felt) -> (completed: felt):
end

@storage_var
func last_referral_time(user: felt) -> (timestamp: felt):
end

@storage_var
func reward_token() -> (token_address: felt):
end

@storage_var
func reward_amount() -> (amount: Uint256):
end

@storage_var
func cooldown_period() -> (seconds: felt):
end

@storage_var
func owner() -> (address: felt):
end

@storage_var
func job_agreement_contract() -> (address: felt):
end

// Constants
const JOB_STATE_COMPLETED = 3

// Events
@event
func ReferralCreated(referrer: felt, referee: felt):
end

@event
func RewardClaimed(referrer: felt, referee: felt, amount: Uint256):
end

@event
func RewardConfigUpdated(token: felt, amount: Uint256):
end

@event
func CooldownUpdated(period: felt):
end

// Constructor
@constructor
func constructor(
    owner_address: felt,
    job_agreement_address: felt,
    token_address: felt,
    initial_reward_amount: Uint256,
    initial_cooldown_period: felt
):
    owner.write(owner_address)
    job_agreement_contract.write(job_agreement_address)
    reward_token.write(token_address)
    reward_amount.write(initial_reward_amount)
    cooldown_period.write(initial_cooldown_period)
    return ()
end

// Only owner modifier
@private
func assert_only_owner{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}():
    let (caller) = get_caller_address()
    let (current_owner) = owner.read()
    assert caller = current_owner
    with_attr error_message("Caller is not the owner") {}
    return ()
end

// Create a referral relationship
@external
func create_referral{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(referrer: felt, referee: felt) -> (success: felt):
    alloc_locals
    
    // Get caller
    let (caller) = get_caller_address()
    
    // Ensure caller is the referrer (you can only create referrals for yourself)
    assert caller = referrer
    with_attr error_message("Only referrer can create referrals") {}
    
    // Prevent self-referrals
    assert referrer != referee
    with_attr error_message("Cannot refer yourself") {}
    
    // Check if referee already has a referrer
    let (existing_referrer) = referrals.read(referee)
    assert existing_referrer = 0
    with_attr error_message("Referee already has a referrer") {}
    
    // Check cooldown period
    let (current_time) = get_block_timestamp()
    let (last_time) = last_referral_time.read(referrer)
    let (cooldown) = cooldown_period.read()
    
    // Ensure cooldown has passed
    assert current_time - last_time >= cooldown
    with_attr error_message("Cooldown period not elapsed") {}
    
    // Create referral relationship
    referrals.write(referee, referrer)
    
    // Update last referral time
    last_referral_time.write(referrer, current_time)
    
    // Emit event
    ReferralCreated.emit(referrer, referee)
    
    return (TRUE)
end

// Process job completion and reward referrer if needed
@external
func process_job_completion{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(job_id: felt) -> (success: felt):
    alloc_locals
    
    // Get job agreement contract
    let (job_contract) = job_agreement_contract.read()
    
    // Verify job is completed
    let (state) = IJobAgreement.job_state(job_contract, job_id)
    assert state = JOB_STATE_COMPLETED
    with_attr error_message("Job not completed") {}
    
    // Get freelancer of the job
    let (freelancer) = IJobAgreement.freelancer_of(job_contract, job_id)
    
    // Check if freelancer already has a completed job
    let (has_completed) = has_completed_job.read(freelancer)
    
    // If freelancer has already completed a job, no reward
    if has_completed = TRUE:
        return (TRUE)
    end
    
    // Mark freelancer as having completed a job
    has_completed_job.write(freelancer, TRUE)
    
    // Check if freelancer has a referrer
    let (referrer) = referrals.read(freelancer)
    
    // If no referrer, no reward
    if referrer = 0:
        return (TRUE)
    end
    
    // Get reward token and amount
    let (token) = reward_token.read()
    let (amount) = reward_amount.read()
    
    // Send reward to referrer
    let (success) = IERC20.transfer(token, referrer, amount)
    assert success = TRUE
    with_attr error_message("Token transfer failed") {}
    
    // Emit event
    RewardClaimed.emit(referrer, freelancer, amount)
    
    return (TRUE)
end

// Update reward configuration (owner only)
@external
func update_reward_config{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(token_address: felt, reward_amount_: Uint256):
    assert_only_owner()
    
    reward_token.write(token_address)
    reward_amount.write(reward_amount_)
    
    RewardConfigUpdated.emit(token_address, reward_amount_)
    return ()
end

// Update cooldown period (owner only)
@external
func update_cooldown{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(new_cooldown: felt):
    assert_only_owner()
    
    cooldown_period.write(new_cooldown)
    
    CooldownUpdated.emit(new_cooldown)
    return ()
end

// View functions
@view
func get_referrer(referee: felt) -> (referrer: felt):
    let (referrer) = referrals.read(referee)
    return (referrer)
end

@view
func check_user_completed_job(user: felt) -> (completed: felt):
    let (completed) = has_completed_job.read(user)
    return (completed)
end

@view
func get_reward_config() -> (token: felt, amount: Uint256):
    let (token) = reward_token.read()
    let (amount) = reward_amount.read()
    return (token, amount)
end

@view
func get_cooldown_period() -> (seconds: felt):
    let (seconds) = cooldown_period.read()
    return (seconds)
end

@view
func get_time_until_next_referral(user: felt) -> (seconds: felt):
    let (current_time) = get_block_timestamp()
    let (last_time) = last_referral_time.read(user)
    let (cooldown) = cooldown_period.read()
    
    let elapsed = current_time - last_time
    
    if elapsed >= cooldown:
        return (0)
    end
    
    return (cooldown - elapsed)
end 
