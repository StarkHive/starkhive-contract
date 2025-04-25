// SPDX-License-Identifier: MIT
// Job Agreement contract for StarkHive

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.syscalls import emit_event

@contract_interface
namespace IJobAgreement:
    func propose_job(recruiter: felt, freelancer: felt, metadata_hash: felt) -> (job_id: felt):
    end
    func accept_job(job_id: felt):
    end
    func activate_job(job_id: felt):
    end
    func complete_job(job_id: felt):
    end
    func dispute_job(job_id: felt):
    end
    func add_milestone(job_id: felt, milestone_hash: felt):
    end
    func mark_milestone_complete(job_id: felt, milestone_id: felt):
    end
end

@storage_var
def job_state(job_id: felt) -> felt:
end

@storage_var
def recruiter_of(job_id: felt) -> felt:
end

@storage_var
def freelancer_of(job_id: felt) -> felt:
end

@storage_var
def metadata_of(job_id: felt) -> felt:
end

@storage_var
def milestone_count(job_id: felt) -> felt:
end

@storage_var
def milestone_hash(job_id: felt, milestone_id: felt) -> felt:
end

# Enum for job states
const JOB_STATE_PROPOSED = 0
const JOB_STATE_ACCEPTED = 1
const JOB_STATE_ACTIVE = 2
const JOB_STATE_COMPLETED = 3
const JOB_STATE_DISPUTED = 4

# Events
@event
def JobProposed(job_id: felt, recruiter: felt, freelancer: felt, metadata_hash: felt):
end

@event
def JobAccepted(job_id: felt, freelancer: felt):
end

@event
def JobActivated(job_id: felt):
end

@event
def JobCompleted(job_id: felt):
end

@event
def JobDisputed(job_id: felt, disputer: felt):
end

@event
def MilestoneAdded(job_id: felt, milestone_id: felt, milestone_hash: felt):
end

@event
def MilestoneCompleted(job_id: felt, milestone_id: felt):
end

@constructor
def constructor():
    return ()
end

# Unique job id counter
@storage_var
def job_counter() -> felt:
end

# Propose a job
@external
def propose_job(recruiter: felt, freelancer: felt, metadata_hash: felt) -> (job_id: felt):
    let (caller) = get_caller_address()
    assert recruiter == caller, 'Only recruiter can propose job'
    let (counter) = job_counter.read()
    let job_id = counter + 1
    job_counter.write(job_id)
    job_state.write(job_id, JOB_STATE_PROPOSED)
    recruiter_of.write(job_id, recruiter)
    freelancer_of.write(job_id, freelancer)
    metadata_of.write(job_id, metadata_hash)
    milestone_count.write(job_id, 0)
    emit JobProposed(job_id, recruiter, freelancer, metadata_hash)
    return (job_id,)
end

# Freelancer accepts the job
@external
def accept_job(job_id: felt):
    let (caller) = get_caller_address()
    let (freelancer) = freelancer_of.read(job_id)
    assert caller == freelancer, 'Only assigned freelancer can accept'
    let (state) = job_state.read(job_id)
    assert state == JOB_STATE_PROPOSED, 'Job not in Proposed state'
    job_state.write(job_id, JOB_STATE_ACCEPTED)
    emit JobAccepted(job_id, freelancer)
    return ()
end

# Recruiter activates the job
@external
def activate_job(job_id: felt):
    let (caller) = get_caller_address()
    let (recruiter) = recruiter_of.read(job_id)
    assert caller == recruiter, 'Only recruiter can activate'
    let (state) = job_state.read(job_id)
    assert state == JOB_STATE_ACCEPTED, 'Job not in Accepted state'
    job_state.write(job_id, JOB_STATE_ACTIVE)
    emit JobActivated(job_id)
    return ()
end

# Complete the job
@external
def complete_job(job_id: felt):
    let (caller) = get_caller_address()
    let (recruiter) = recruiter_of.read(job_id)
    let (freelancer) = freelancer_of.read(job_id)
    let (state) = job_state.read(job_id)
    assert state == JOB_STATE_ACTIVE, 'Job not in Active state'
    assert caller == recruiter or caller == freelancer, 'Only recruiter or freelancer can complete'
    job_state.write(job_id, JOB_STATE_COMPLETED)
    emit JobCompleted(job_id)
    return ()
end

# Dispute the job
@external
def dispute_job(job_id: felt):
    let (caller) = get_caller_address()
    let (recruiter) = recruiter_of.read(job_id)
    let (freelancer) = freelancer_of.read(job_id)
    let (state) = job_state.read(job_id)
    assert state != JOB_STATE_COMPLETED, 'Cannot dispute completed job'
    assert caller == recruiter or caller == freelancer, 'Only parties can dispute'
    job_state.write(job_id, JOB_STATE_DISPUTED)
    emit JobDisputed(job_id, caller)
    return ()
end

# Add a milestone (recruiter only, before activation)
@external
def add_milestone(job_id: felt, milestone_hash: felt):
    let (caller) = get_caller_address()
    let (recruiter) = recruiter_of.read(job_id)
    let (state) = job_state.read(job_id)
    assert caller == recruiter, 'Only recruiter can add milestone'
    assert state == JOB_STATE_PROPOSED or state == JOB_STATE_ACCEPTED, 'Can only add milestone before activation'
    let (count) = milestone_count.read(job_id)
    let milestone_id = count + 1
    milestone_hash.write(job_id, milestone_id, milestone_hash)
    milestone_count.write(job_id, milestone_id)
    emit MilestoneAdded(job_id, milestone_id, milestone_hash)
    return ()
end

# Mark milestone complete (freelancer only, when active)
@external
def mark_milestone_complete(job_id: felt, milestone_id: felt):
    let (caller) = get_caller_address()
    let (freelancer) = freelancer_of.read(job_id)
    let (state) = job_state.read(job_id)
    assert caller == freelancer, 'Only freelancer can complete milestone'
    assert state == JOB_STATE_ACTIVE, 'Job must be active'
    let (hash) = milestone_hash.read(job_id, milestone_id)
    assert hash != 0, 'Milestone does not exist'
    emit MilestoneCompleted(job_id, milestone_id)
    return ()
end
