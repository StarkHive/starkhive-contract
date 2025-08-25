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
