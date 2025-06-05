use starkhive_contract::base::types::{ArbitratorInfo, Dispute, VoteInfo};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IProfileRegistry<TContractState> {
    // === Profile Actions ===
    fn register_profile(ref self: TContractState, username: felt252, bio: felt252, avatar: felt252);

    fn update_profile(ref self: TContractState, field: felt252, value: felt252);

    fn toggle_profile_visibility(ref self: TContractState);

    // === Portfolio Links ===
    fn add_portfolio_link(ref self: TContractState, link: felt252);

    fn get_portfolio_link(self: @TContractState, user: ContractAddress, index: u256) -> felt252;
    fn get_portfolio_count(self: @TContractState, user: ContractAddress) -> u256;

    // === Skills ===
    fn add_skill(ref self: TContractState, skill: felt252);
    fn verify_skill(ref self: TContractState, user: ContractAddress, skill: felt252);

    fn get_skill(self: @TContractState, user: ContractAddress, index: u256) -> felt252;
    fn get_skill_count(self: @TContractState, user: ContractAddress) -> u256;
    fn is_skill_verified(self: @TContractState, user: ContractAddress, skill: felt252) -> bool;

    // === Work Experience ===
    fn add_work_entry(
        ref self: TContractState, org: felt252, role: felt252, months: u32, description: felt252,
    );

    fn get_work_entry(self: @TContractState, user: ContractAddress, index: u256) -> WorkEntry;
    fn get_work_entry_count(self: @TContractState, user: ContractAddress) -> u256;

    // === Profile + Reputation Views ===
    fn get_profile(self: @TContractState, user: ContractAddress) -> Profile;
    fn get_reputation_score(self: @TContractState, user: ContractAddress) -> u256;
    fn is_profile_public(self: @TContractState, user: ContractAddress) -> bool;
}
