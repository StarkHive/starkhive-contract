use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::get_block_timestamp;

#[starknet::interface]
trait IDisputeResolution<TContractState> {
    fn initiate_dispute(
        ref self: TContractState,
        escrow_id: u256,
        disputed_amount: u256,
        evidence_hash: felt252,
        description: felt252
    ) -> u256;
    
    fn submit_evidence(
        ref self: TContractState,
        dispute_id: u256,
        evidence_hash: felt252,
        evidence_type: u8
    );
    
    fn select_arbitrators(
        ref self: TContractState,
        dispute_id: u256,
        arbitrator_count: u8
    );
    
    fn cast_vote(
        ref self: TContractState,
        dispute_id: u256,
        vote: u8, // 0 = reject, 1 = approve, 2 = partial
        reasoning: felt252
    );
    
    fn execute_resolution(ref self: TContractState, dispute_id: u256);
    
    fn initiate_appeal(
        ref self: TContractState,
        dispute_id: u256,
        appeal_evidence: felt252
    ) -> u256;
    
    fn add_arbitrator(
        ref self: TContractState,
        arbitrator: ContractAddress,
        reputation_score: u256
    );
    
    fn get_dispute_details(self: @TContractState, dispute_id: u256) -> DisputeInfo;
}

#[derive(Drop, Serde, starknet::Store)]
struct DisputeInfo {
    id: u256,
    initiator: ContractAddress,
    respondent: ContractAddress,
    escrow_id: u256,
    disputed_amount: u256,
    status: DisputeStatus,
    created_at: u64,
    voting_deadline: u64,
    evidence_count: u32,
    arbitrator_votes: u32,
    total_arbitrators: u32,
    resolution: DisputeResolution,
    appeal_count: u8,
}

#[derive(Drop, Serde, starknet::Store)]
enum DisputeStatus {
    Initiated,
    ArbitratorsSelected,
    EvidenceSubmission,
    Voting,
    Resolved,
    Appealed,
    Finalized,
}

#[derive(Drop, Serde, starknet::Store)]
enum DisputeResolution {
    Pending,
    ApproveInitiator,
    ApproveRespondent,
    PartialResolution: u256, // percentage to initiator
}

#[derive(Drop, Serde, starknet::Store)]
struct Evidence {
    submitter: ContractAddress,
    evidence_hash: felt252,
    evidence_type: u8, // 1 = document, 2 = transaction, 3 = witness
    timestamp: u64,
}

#[derive(Drop, Serde, starknet::Store)]
struct Arbitrator {
    address: ContractAddress,
    reputation_score: u256,
    total_cases: u32,
    successful_cases: u32,
    is_active: bool,
}

#[derive(Drop, Serde, starknet::Store)]
struct Vote {
    arbitrator: ContractAddress,
    vote: u8,
    weight: u256,
    reasoning: felt252,
    timestamp: u64,
}
