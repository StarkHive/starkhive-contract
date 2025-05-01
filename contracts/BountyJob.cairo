
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.starknet.common.syscalls import emit_event

@contract_interface
namespace IBountyJob:
    func create_bounty(reward_amount: Uint256, metadata_hash: felt, expiration_time: felt) -> (bounty_id: felt):
    end
    func submit_solution(bounty_id: felt, solution_hash: felt) -> (submission_id: felt):
    end
    func select_winner(bounty_id: felt, submission_id: felt):
    end
    func claim_reward(bounty_id: felt):
    end
    func check_expiration(bounty_id: felt) -> (is_expired: felt):
    end
    func get_bounty_details(bounty_id: felt) -> (
        recruiter: felt, reward_amount: Uint256, metadata_hash: felt, 
        status: felt, expiration_time: felt, winner: felt
    ):
    end
    func get_submission_count(bounty_id: felt) -> (count: felt):
    end
    func get_submission(bounty_id: felt, submission_id: felt) -> (
        submitter: felt, solution_hash: felt, submission_time: felt
    ):
    end
end

@storage_var
func bounty_state(bounty_id: felt) -> felt:
end

@storage_var
func recruiter_of(bounty_id: felt) -> felt:
end

@storage_var
func reward_amount(bounty_id: felt) -> (amount: Uint256):
end

@storage_var
func metadata_of(bounty_id: felt) -> felt:
end

@storage_var
func expiration_time(bounty_id: felt) -> felt:
end

@storage_var
func winner_of(bounty_id: felt) -> felt:
end

@storage_var
func bounty_counter() -> felt:
end

@storage_var
func submission_counter(bounty_id: felt) -> felt:
end

@storage_var
func submitter_of(bounty_id: felt, submission_id: felt) -> felt:
end

@storage_var
func solution_hash(bounty_id: felt, submission_id: felt) -> felt:
end

@storage_var
func submission_time(bounty_id: felt, submission_id: felt) -> felt:
end

@storage_var
func winning_submission_id(bounty_id: felt) -> felt:
end

// Enum for bounty states
const BOUNTY_STATE_ACTIVE = 0
const BOUNTY_STATE_EXPIRED = 1
const BOUNTY_STATE_WINNER_SELECTED = 2
const BOUNTY_STATE_COMPLETED = 3

// Events
@event
func BountyCreated(bounty_id: felt, recruiter: felt, reward_amount: Uint256, metadata_hash: felt, expiration_time: felt):
end

@event
func SolutionSubmitted(bounty_id: felt, submission_id: felt, submitter: felt, solution_hash: felt):
end

@event
func WinnerSelected(bounty_id: felt, submission_id: felt, winner: felt):
end

@event
func RewardClaimed(bounty_id: felt, winner: felt, reward_amount: Uint256):
end

@event
func BountyExpired(bounty_id: felt, expiration_time: felt):
end

@constructor
func constructor():
    return ()
end

// Create a new bounty job
@external
func create_bounty(reward_amount: Uint256, metadata_hash: felt, expiration_time: felt) -> (bounty_id: felt):
    alloc_locals
    let (caller) = get_caller_address()
    let (current_time) = get_block_timestamp()
    
    assert expiration_time > current_time, 'Expiration must be in future'
    
    let (counter) = bounty_counter.read()
    let bounty_id = counter + 1
    bounty_counter.write(bounty_id)
    
    bounty_state.write(bounty_id, BOUNTY_STATE_ACTIVE)
    recruiter_of.write(bounty_id, caller)
    reward_amount.write(bounty_id, reward_amount)
    metadata_of.write(bounty_id, metadata_hash)
    expiration_time.write(bounty_id, expiration_time)
    submission_counter.write(bounty_id, 0)
    
    emit BountyCreated(bounty_id, caller, reward_amount, metadata_hash, expiration_time)
    
    return (bounty_id)
end

@external
func submit_solution(bounty_id: felt, solution_hash: felt) -> (submission_id: felt):
    alloc_locals
    let (caller) = get_caller_address()
    let (current_time) = get_block_timestamp()
    
    let (state) = bounty_state.read(bounty_id)
    assert state == BOUNTY_STATE_ACTIVE, 'Bounty not active'
    
    let (is_expired) = check_expiration(bounty_id)
    assert is_expired == 0, 'Bounty has expired'
    
    let (counter) = submission_counter.read(bounty_id)
    let submission_id = counter + 1
    submission_counter.write(bounty_id, submission_id)
    
    submitter_of.write(bounty_id, submission_id, caller)
    solution_hash.write(bounty_id, submission_id, solution_hash)
    submission_time.write(bounty_id, submission_id, current_time)
    
    emit SolutionSubmitted(bounty_id, submission_id, caller, solution_hash)
    
    return (submission_id)
end

@external
func select_winner(bounty_id: felt, submission_id: felt):
    alloc_locals
    let (caller) = get_caller_address()
    
    let (recruiter) = recruiter_of.read(bounty_id)
    assert caller == recruiter, 'Only recruiter can select winner'
    
    let (state) = bounty_state.read(bounty_id)
    assert state == BOUNTY_STATE_ACTIVE, 'Bounty not active'
    
    let (submitter) = submitter_of.read(bounty_id, submission_id)
    assert submitter != 0, 'Submission does not exist'
    
    winner_of.write(bounty_id, submitter)
    winning_submission_id.write(bounty_id, submission_id)
    bounty_state.write(bounty_id, BOUNTY_STATE_WINNER_SELECTED)
    
    emit WinnerSelected(bounty_id, submission_id, submitter)
    
    return ()
end

@external
func claim_reward(bounty_id: felt):
    alloc_locals
    let (caller) = get_caller_address()
    
    let (winner) = winner_of.read(bounty_id)
    assert caller == winner, 'Only winner can claim reward'
    
    let (state) = bounty_state.read(bounty_id)
    assert state == BOUNTY_STATE_WINNER_SELECTED, 'Winner not yet selected'
    
    let (reward) = reward_amount.read(bounty_id)
    
    bounty_state.write(bounty_id, BOUNTY_STATE_COMPLETED)
    
    emit RewardClaimed(bounty_id, winner, reward)
    
    return ()
end

@external
func check_expiration(bounty_id: felt) -> (is_expired: felt):
    alloc_locals
    let (current_time) = get_block_timestamp()
    let (expiry) = expiration_time.read(bounty_id)
    let (state) = bounty_state.read(bounty_id)
    
    if current_time > expiry and state == BOUNTY_STATE_ACTIVE:
        bounty_state.write(bounty_id, BOUNTY_STATE_EXPIRED)
        emit BountyExpired(bounty_id, expiry)
        return (1)  // 1 means expired
    end
    
    if state == BOUNTY_STATE_EXPIRED:
        return (1)  // 1 means expired
    end
    
    return (0)  // 0 means not expired
end

@view
func get_bounty_details(bounty_id: felt) -> (
    recruiter: felt, reward_amount: Uint256, metadata_hash: felt, 
    status: felt, expiration_time: felt, winner: felt
):
    alloc_locals
    let (recruiter) = recruiter_of.read(bounty_id)
    let (reward) = reward_amount.read(bounty_id)
    let (metadata) = metadata_of.read(bounty_id)
    let (state) = bounty_state.read(bounty_id)
    let (expiry) = expiration_time.read(bounty_id)
    let (winner) = winner_of.read(bounty_id)
    
    let (is_expired) = check_expiration(bounty_id)
    
    if is_expired == 1:
        return (recruiter, reward, metadata, BOUNTY_STATE_EXPIRED, expiry, winner)
    end
    
    return (recruiter, reward, metadata, state, expiry, winner)
end

@view
func get_submission_count(bounty_id: felt) -> (count: felt):
    let (count) = submission_counter.read(bounty_id)
    return (count)
end

// Get specific submission details
@view
func get_submission(bounty_id: felt, submission_id: felt) -> (
    submitter: felt, solution_hash: felt, submission_time: felt
):
    let (submitter) = submitter_of.read(bounty_id, submission_id)
    let (hash) = solution_hash.read(bounty_id, submission_id)
    let (time) = submission_time.read(bounty_id, submission_id)
    
    return (submitter, hash, time)
end
