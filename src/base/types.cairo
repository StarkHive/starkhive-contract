use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct Job {
    pub job_id: u256,
    pub title: felt252,
    pub description: ByteArray,
    pub budget: u256,
    pub deadline: u64,
    pub requirements: ByteArray,
    pub owner: ContractAddress,
    pub status: Status,
    pub applications: u256,
    pub applicant: ContractAddress,
    pub updated_at: u64,
    pub created_at: u64,
}

#[derive(Drop, Serde, starknet::Store, Clone)]
pub struct Applicant {
    pub address: ContractAddress,
    pub job_id: u256,
    pub applicant_id: u256,
    pub qualification: ByteArray,
    pub application_status: ApplicationStatus,
    pub updated_at: u64,
    pub applied_at: u64,
}

#[derive(Debug, Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum Status {
    #[default]
    Open,
    InProgress,
    Reviewing,
    Completed,
    Rejected,
    Disputed,
    Cancelled,
}

#[derive(Debug, Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum ApplicationStatus {
    #[default]
    NotApplied,
    Assigned,
    Pending,
    Reviewing,
    Accepted,
    Rejected,
    JobCancelled,
}

