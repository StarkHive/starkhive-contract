// SPDX-License-Identifier: MIT
// Job Agreement contract for StarkHive

%lang starknet

from starkware.starknet.common.syscalls import (
    get_caller_address,
    create_contract
)

// Event emitted when a new job is deployed
@event
func JobDeployed(job_address: felt) {
}

// Storage variables
@storage_var
func job_agreement_class_hash() -> (class_hash: felt) {
}

@storage_var
func deploy_nonce() -> (nonce: felt) {
}

@storage_var
func user_jobs_count(user: felt) -> (count: felt) {
}

@storage_var
func user_jobs(user: felt, index: felt) -> (job_address: felt) {
}

// Constructor initializes the job agreement class hash
@constructor
func constructor(job_agreement_class_hash_: felt) {
    job_agreement_class_hash.write(job_agreement_class_hash_);
    deploy_nonce.write(0);
    return ();
}

// Creates a new job agreement contract
@external
func create_job(constructor_calldata_len: felt, constructor_calldata: felt*) {
    alloc_locals;
    
    // Get caller address
    let caller = get_caller_address();
    
    // Read contract parameters from storage
    let (class_hash) = job_agreement_class_hash.read();
    let (nonce) = deploy_nonce.read();
    
    // Deploy new job agreement contract
    let (deployed_address, _) = create_contract(
        class_hash=class_hash,
        contract_address_salt=nonce,
        constructor_calldata=constructor_calldata,
        constructor_calldata_size=constructor_calldata_len
    );
    
    // Update deployment nonce
    deploy_nonce.write(nonce + 1);
    
    // Update user's job tracking
    let (count) = user_jobs_count.read(caller);
    user_jobs.write(caller, count, deployed_address);
    user_jobs_count.write(caller, count + 1);
    
    // Emit deployment event
    JobDeployed.emit(job_address=deployed_address);
    return ();
}

// Returns all job addresses for a given user
@view
func get_user_jobs(user: felt) -> (len: felt, jobs: felt*) {
    alloc_locals;
    let (count) = user_jobs_count.read(user);
    let (jobs) = alloc_local(count);
    
    // Populate jobs array
    let i = 0;
    loop {
        if i == count {
            break;
        }
        let (job) = user_jobs.read(user, i);
        assert [jobs + i] = job;
        i = i + 1;
    };
    return (count, jobs);
}