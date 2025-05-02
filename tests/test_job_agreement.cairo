// // Cairo-native tests for JobAgreement contract (snforge compatible)

// %lang starknet

// from starkware.cairo.common.cairo_builtins import HashBuiltin
// from contracts.JobAgreement import JobAgreement

// const RECRUITER = 0x111;
// const FREELANCER = 0x222;
// const META_HASH = 0xabc;
// const MILESTONE_HASH = 0xdef;

// @contract_interface
// namespace IJobAgreement {
//     func propose_job(recruiter: felt, freelancer: felt, metadata_hash: felt) -> (job_id: felt);
//     func accept_job(job_id: felt);
//     func activate_job(job_id: felt);
//     func complete_job(job_id: felt);
//     func dispute_job(job_id: felt);
//     func add_milestone(job_id: felt, milestone_hash: felt);
//     func mark_milestone_complete(job_id: felt, milestone_id: felt);
//     func job_state(job_id: felt) -> (state: felt);
//     func recruiter_of(job_id: felt) -> (recruiter: felt);
//     func freelancer_of(job_id: felt) -> (freelancer: felt);
//     func milestone_count(job_id: felt) -> (count: felt);
// end

// #[test]
// func test_propose_accept_activate_complete() {
//     let contract = JobAgreement.deploy();
//     let (job_id) = contract.propose_job(RECRUITER, FREELANCER, META_HASH);
//     let (state) = contract.job_state(job_id);
//     assert(state == 0, 'Job should be Proposed');
//     let (recruiter) = contract.recruiter_of(job_id);
//     let (freelancer) = contract.freelancer_of(job_id);
//     assert(recruiter == RECRUITER, 'Recruiter mapping');
//     assert(freelancer == FREELANCER, 'Freelancer mapping');

//     contract.accept_job(job_id);
//     let (state2) = contract.job_state(job_id);
//     assert(state2 == 1, 'Job should be Accepted');

//     contract.activate_job(job_id);
//     let (state3) = contract.job_state(job_id);
//     assert(state3 == 2, 'Job should be Active');

//     contract.complete_job(job_id);
//     let (state4) = contract.job_state(job_id);
//     assert(state4 == 3, 'Job should be Completed');
//     return ();
// }

// #[test]
// func test_add_and_complete_milestone() {
//     let contract = JobAgreement.deploy();
//     let (job_id) = contract.propose_job(RECRUITER, FREELANCER, META_HASH);
//     contract.add_milestone(job_id, MILESTONE_HASH);
//     let (count) = contract.milestone_count(job_id);
//     assert(count == 1, 'Milestone should be added');

//     contract.accept_job(job_id);
//     contract.activate_job(job_id);
//     contract.mark_milestone_complete(job_id, 1);
//     // Optionally check state or events if needed
//     return ();
// }

// #[test]
// func test_dispute_job() {
//     let contract = JobAgreement.deploy();
//     let (job_id) = contract.propose_job(RECRUITER, FREELANCER, META_HASH);
//     contract.accept_job(job_id);
//     contract.activate_job(job_id);
//     contract.dispute_job(job_id);
//     let (state) = contract.job_state(job_id);
//     assert(state == 4, 'Job should be Disputed');
//     return ();
// }
//     await contract.activate_job(job_id).invoke(caller_address=RECRUITER)
//     # Only recruiter or freelancer can complete
//     with pytest.raises(Exception):
//         await contract.complete_job(job_id).invoke(caller_address=OTHER)
//     await contract.complete_job(job_id).invoke(caller_address=RECRUITER)
//     state = await contract.job_state(job_id).call()
//     assert state.result.res == 3  # JOB_STATE_COMPLETED
//     # Cannot complete again
//     with pytest.raises(Exception):
//         await contract.complete_job(job_id).invoke(caller_address=FREELANCER)

// @pytest.mark.asyncio
// async def test_dispute_job(job_agreement_contract):
//     contract = job_agreement_contract
//     exec_info = await contract.propose_job(RECRUITER, FREELANCER, META_HASH).invoke(caller_address=RECRUITER)
//     job_id = exec_info.result.job_id
//     # Only parties can dispute
//     with pytest.raises(Exception):
//         await contract.dispute_job(job_id).invoke(caller_address=OTHER)
//     await contract.dispute_job(job_id).invoke(caller_address=RECRUITER)
//     state = await contract.job_state(job_id).call()
//     assert state.result.res == 4  # JOB_STATE_DISPUTED
//     # Cannot dispute completed job
//     exec_info2 = await contract.propose_job(RECRUITER, FREELANCER, META_HASH).invoke(caller_address=RECRUITER)
//     job_id2 = exec_info2.result.job_id
//     await contract.accept_job(job_id2).invoke(caller_address=FREELANCER)
//     await contract.activate_job(job_id2).invoke(caller_address=RECRUITER)
//     await contract.complete_job(job_id2).invoke(caller_address=RECRUITER)
//     with pytest.raises(Exception):
//         await contract.dispute_job(job_id2).invoke(caller_address=RECRUITER)

// @pytest.mark.asyncio
// async def test_add_and_complete_milestone(job_agreement_contract):
//     contract = job_agreement_contract
//     exec_info = await contract.propose_job(RECRUITER, FREELANCER, META_HASH).invoke(caller_address=RECRUITER)
//     job_id = exec_info.result.job_id
//     # Only recruiter can add milestone
//     with pytest.raises(Exception):
//         await contract.add_milestone(job_id, MILESTONE_HASH).invoke(caller_address=FREELANCER)
//     await contract.add_milestone(job_id, MILESTONE_HASH).invoke(caller_address=RECRUITER)
//     count = await contract.milestone_count(job_id).call()
//     assert count.result.res == 1
//     # Only before activation
//     await contract.accept_job(job_id).invoke(caller_address=FREELANCER)
//     await contract.activate_job(job_id).invoke(caller_address=RECRUITER)
//     with pytest.raises(Exception):
//         await contract.add_milestone(job_id, MILESTONE_HASH).invoke(caller_address=RECRUITER)
//     # Only freelancer can mark milestone complete
//     with pytest.raises(Exception):
//         await contract.mark_milestone_complete(job_id, 1).invoke(caller_address=RECRUITER)
//     await contract.mark_milestone_complete(job_id, 1).invoke(caller_address=FREELANCER)
//     # Milestone must exist
//     with pytest.raises(Exception):
//         await contract.mark_milestone_complete(job_id, 2).invoke(caller_address=FREELANCER)
