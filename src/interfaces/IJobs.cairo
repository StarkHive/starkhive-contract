use starkhive_contract::base::types::{Applicant, Job};
use starknet::ContractAddress;
#[starknet::interface]
pub trait IJobs<TContractState> {
    fn register(ref self: TContractState);
    fn create_job(
        ref self: TContractState,
        token: ContractAddress,
        title: felt252,
        description: ByteArray,
        budget: u256,
        deadline: u64,
        requirements: ByteArray,
        owner: ContractAddress,
    ) -> u256;

    fn pay_applicant(
        ref self: TContractState, token: ContractAddress, receiver: ContractAddress, amount: u256,
    ) -> bool;
    fn deposit(
        ref self: TContractState, token: ContractAddress, depositor: ContractAddress, amount: u256,
    ) -> bool;

    fn check_balance(
        self: @TContractState, token: ContractAddress, address: ContractAddress,
    ) -> u256;

    fn apply_for_job(ref self: TContractState, job_id: u256, qualification: ByteArray) -> u256;
    fn get_applicant(self: @TContractState, job_id: u256, applicant_id: u256) -> Applicant;
    fn assign_job(ref self: TContractState, job_id: u256, applicant_id: u256);
    fn get_job(self: @TContractState, job_id: u256) -> Job;
    fn submit_job(ref self: TContractState, job_id: u256, applicant_id: u256);
    fn approve_submission(
        ref self: TContractState, token: ContractAddress, job_id: u256, applicant_id: u256,
    );
    fn cancel_job(ref self: TContractState, token: ContractAddress, job_id: u256);
    fn reject_submission(ref self: TContractState, job_id: u256, applicant_id: u256);
    fn request_changes(ref self: TContractState, job_id: u256, applicant_id: u256);
    fn get_all_job_applicants(self: @TContractState, job_id: u256) -> Array<Applicant>;
}
