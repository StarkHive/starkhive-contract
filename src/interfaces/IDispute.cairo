use starkhive_contract::base::types::{ArbitratorInfo, Dispute, VoteInfo};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IDispute<TContractState> {
    fn init(ref self: TContractState, multi_sig: ContractAddress);

    fn initiate_dispute(
        ref self: TContractState,
        job_id: u256,
        claimant: ContractAddress,
        respondent: ContractAddress,
    ) -> u256;

    fn submit_evidence(ref self: TContractState, dispute_id: u256, data: ByteArray);

    fn vote(ref self: TContractState, dispute_id: u256, support: bool);

    fn resolve_dispute(ref self: TContractState, dispute_id: u256);

    fn appeal_dispute(ref self: TContractState, dispute_id: u256);

    fn penalise_false_dispute(ref self: TContractState, dispute_id: u256);

    fn get_dispute(self: @TContractState, dispute_id: u256) -> Dispute;
    fn get_vote(self: @TContractState, dispute_id: u256, arbitrator: ContractAddress) -> VoteInfo;
    fn get_arbitrator(self: @TContractState, address: ContractAddress) -> ArbitratorInfo;
}
