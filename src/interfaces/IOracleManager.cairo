// SPDX-License-Identifier: MIT
// IOracleManager: Interface for price feed and conversion utilities

use starknet::ContractAddress;

#[starknet::interface]
pub trait IOracleManager<TContractState> {
    fn get_price(self: @TContractState, token: felt252) -> (u256, u8, OracleStatus);
    fn to_usd(self: @TContractState, token: felt252, amount: u256) -> (u256, OracleStatus);
    fn get_exchange_rate(self: @TContractState, token: felt252) -> (u256, u8, OracleStatus);
    fn is_stale(self: @TContractState, token: felt252) -> bool;
    fn last_update_time(self: @TContractState, token: felt252) -> u64;
    fn get_fallback_price(self: @TContractState, token: felt252) -> u256;
}

#[derive(Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum OracleStatus {
    #[default]
    Ok,
    Stale,
    Missing,
    Fallback,
}
