// SPDX-License-Identifier: MIT
// Referral Reward contract for StarkHive

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
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