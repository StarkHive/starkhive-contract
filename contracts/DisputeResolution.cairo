%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_lt

@storage_var
func disputes(dispute_id: felt) -> (party_a: felt, party_b: felt, stake_amount: felt, votes_for_a: felt, votes_for_b: felt, status: felt, resolved_winner: felt):
end

@storage_var
func arbitrators(address: felt) -> (is_arbitrator: felt):
end

@storage_var
func dispute_votes(dispute_id: felt, voter: felt) -> (has_voted: felt):
end

@external
func open_dispute{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(dispute_id: felt, party_a: felt, party_b: felt, stake_amount: felt):
    let (status) = disputes.read(dispute_id).status
    assert status = 0  // must be fresh
    disputes.write(dispute_id, party_a, party_b, stake_amount, 0, 0, 0, 0)
    return ()
end

@external
func add_arbitrator{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(address: felt):
    arbitrators.write(address, 1)
    return ()
end

@external
func remove_arbitrator{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(address: felt):
    arbitrators.write(address, 0)
    return ()
end

@external
func vote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(dispute_id: felt, vote_for_party_a: felt):
    let (is_arbitrator) = arbitrators.read(get_caller_address())
    assert is_arbitrator = 1

    let (has_voted) = dispute_votes.read(dispute_id, get_caller_address())
    assert has_voted = 0

    let (party_a, party_b, stake_amount, votes_for_a, votes_for_b, status, resolved_winner) = disputes.read(dispute_id)
    assert status = 0 or status = 1

    if vote_for_party_a == 1:
        let votes_for_a_new = votes_for_a + 1
        disputes.write(dispute_id, party_a, party_b, stake_amount, votes_for_a_new, votes_for_b, 1, 0)
    else:
        let votes_for_b_new = votes_for_b + 1
        disputes.write(dispute_id, party_a, party_b, stake_amount, votes_for_a, votes_for_b_new, 1, 0)

    dispute_votes.write(dispute_id, get_caller_address(), 1)
    return ()
end

@external
func resolve_dispute{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(dispute_id: felt):
    let (party_a, party_b, stake_amount, votes_for_a, votes_for_b, status, resolved_winner) = disputes.read(dispute_id)
    assert status = 1  // must be in review

    if votes_for_a > votes_for_b:
        disputes.write(dispute_id, party_a, party_b, stake_amount, votes_for_a, votes_for_b, 2, party_a)
        # Transfer staked funds to party_a
    else:
        disputes.write(dispute_id, party_a, party_b, stake_amount, votes_for_a, votes_for_b, 2, party_b)
        # Transfer staked funds to party_b
    return ()
end

# Helper function to get the caller address
func get_caller_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (caller: felt):
    alloc_locals
    let (caller) = get_caller_address_syscall()
    return (caller)
end

