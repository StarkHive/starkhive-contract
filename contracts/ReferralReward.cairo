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
=======
from starkware.starknet.common.syscalls import emit_event

// Constants
const COOLDOWN_PERIOD = 604800;  // 7 days in seconds
const REWARD_AMOUNT_LOW = 50000000000000000000;  // 50 tokens low part
const REWARD_AMOUNT_HIGH = 0;  // 50 tokens high part

// Storage variables
@storage_var
func referrers(referee: felt) -> (referrer: felt) {
}

@storage_var
func job_completed(user: felt) -> (completed: felt) {
}

@storage_var
func last_reward_time(referrer: felt) -> (time: felt) {
}

@storage_var
func token_contract() -> (address: felt) {
}

@storage_var
func owner() -> (address: felt) {
}

// Events
@event
func ReferralRegistered(referrer: felt, referee: felt) {
}

@event
func RewardClaimed(referrer: felt, referee: felt, amount_low: felt, amount_high: felt) {
}

@event
func TokenContractChanged(old_token: felt, new_token: felt) {
}

@event
func OwnershipTransferred(previous_owner: felt, new_owner: felt) {
}

// Interface for interacting with ERC20 token
@contract_interface
namespace IERC20 {
    func transfer(recipient: felt, amount_low: felt, amount_high: felt) -> (success: felt) {
    }
    
    func transferFrom(sender: felt, recipient: felt, amount_low: felt, amount_high: felt) -> (success: felt) {
    }
    
    func balanceOf(account: felt) -> (balance_low: felt, balance_high: felt) {
    }
}

// External interface
@contract_interface
namespace IReferralReward {
    func register_referral(referrer: felt) -> (success: felt) {
    }
    
    func complete_job(user: felt) -> (success: felt) {
    }
    
    func get_referrer(referee: felt) -> (referrer: felt) {
    }
    
    func has_completed_job(referee: felt) -> (completed: felt) {
    }
    
    func set_token_contract(token_address: felt) {
    }
    
    func get_token_contract() -> (address: felt) {
    }
    
    func transfer_ownership(new_owner: felt) {
    }
    
    func get_owner() -> (address: felt) {
    }
}

// Constructor
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _owner: felt, _token_address: felt
) {
    assert(_owner != 0, 'Owner cannot be zero');
    assert(_token_address != 0, 'Token cannot be zero');
    
    owner.write(_owner);
    token_contract.write(_token_address);
    return ();
}

// Register a referral relationship
@external
func register_referral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    referrer: felt
) -> (success: felt) {
    let (referee) = get_caller_address();
    
    // Prevent self-referrals
    assert(referee != referrer, 'Cannot refer yourself');
    
    // Check if referee is already registered
    let (current_referrer) = referrers.read(referee);
    assert(current_referrer == 0, 'Already referred');
    
    // Set referrer
    referrers.write(referee, referrer);
    
    // Emit event
    emit_event.emit(ReferralRegistered(referrer, referee));
    
    return (1,);
}

// Mark a job as completed and process rewards
@external
func complete_job{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user: felt
) -> (success: felt) {
    let (caller) = get_caller_address();
    let (current_owner) = owner.read();
    
    // Only owner or authorized contracts can call this
    assert(caller == current_owner, 'Not authorized');
    
    // Check if this is user's first job
    let (completed) = job_completed.read(user);
    if (completed == 0) {
        job_completed.write(user, 1);
        
        // Check if user has a referrer
        let (referrer) = referrers.read(user);
        if (referrer != 0) {
            // Check cooldown period
            let (current_time) = get_block_timestamp();
            let (last_reward) = last_reward_time.read(referrer);
            
            if (current_time >= last_reward + COOLDOWN_PERIOD) {
                // Update last reward time
                last_reward_time.write(referrer, current_time);
                
                // Send reward tokens to referrer
                let (token) = token_contract.read();
                let (success) = IERC20.transfer(
                    contract_address=token,
                    recipient=referrer,
                    amount_low=REWARD_AMOUNT_LOW,
                    amount_high=REWARD_AMOUNT_HIGH
                );
                
                if (success == 1) {
                    // Emit event
                    emit_event.emit(
                        RewardClaimed(
                            referrer=referrer,
                            referee=user,
                            amount_low=REWARD_AMOUNT_LOW,
                            amount_high=REWARD_AMOUNT_HIGH
                        )
                    );
                }
                
                return (success,);
            }
        }
    }
    
    return (1,);
}

// Get the referrer for a given referee
@view
func get_referrer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    referee: felt
) -> (referrer: felt) {
    let (referrer) = referrers.read(referee);
    return (referrer,);
}

// Check if a user has completed a job
@view
func has_completed_job{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    referee: felt
) -> (completed: felt) {
    let (completed) = job_completed.read(referee);
    return (completed,);
}

// Set the token contract address (owner only)
@external
func set_token_contract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_address: felt
) {
    let (caller) = get_caller_address();
    let (current_owner) = owner.read();
    assert(caller == current_owner, 'Not owner');
    assert(token_address != 0, 'Token cannot be zero');
    
    let (old_token) = token_contract.read();
    token_contract.write(token_address);
    
    emit_event.emit(TokenContractChanged(old_token, token_address));
    return ();
}

// Get the current token contract address
@view
func get_token_contract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (address: felt) {
    let (address) = token_contract.read();
    return (address,);
}

// Transfer ownership of the contract
@external
func transfer_ownership{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_owner: felt
) {
    let (caller) = get_caller_address();
    let (current_owner) = owner.read();
    assert(caller == current_owner, 'Not owner');
    assert(new_owner != 0, 'Owner cannot be zero');
    
    owner.write(new_owner);
    
    emit_event.emit(OwnershipTransferred(current_owner, new_owner));
    return ();
}

// Get the current owner address
@view
func get_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (address: felt) {
    let (current_owner) = owner.read();
    return (current_owner,);
} 
