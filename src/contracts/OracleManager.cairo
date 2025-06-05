// SPDX-License-Identifier: MIT
// OracleManager: Modular price feed integration for StarkHive
// Handles Chainlink price feeds, fallback manual prices, and normalization utilities

use starknet::ContractAddress;
use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
use starknet::{get_block_timestamp};
use core::option::OptionTrait;
use core::array::ArrayTrait;

#[derive(Drop, Serde, starknet::Store, Clone, PartialEq)]
pub enum OracleStatus {
    #[default]
    Ok,
    Stale,
    Missing,
    Fallback,
}

#[event]
fn PriceFeedUpdated(token: felt252, price: u256, decimals: u8, source: felt252);
#[event]
fn FallbackPriceUpdated(token: felt252, price: u256, admin: ContractAddress);
#[event]
fn ConversionPerformed(token: felt252, amount: u256, usd_value: u256);

#[storage]
struct Storage {
    // token symbol (felt252) -> Chainlink feed address
    chainlink_feeds: Map<felt252, ContractAddress>,
    // token symbol -> fallback price (admin-set, 18 decimals)
    fallback_prices: Map<felt252, u256>,
    // token symbol -> last update timestamp
    last_update: Map<felt252, u64>,
    // token symbol -> last price
    last_price: Map<felt252, u256>,
    // token symbol -> decimals
    decimals: Map<felt252, u8>,
    // admin address for manual fallback
    admin: ContractAddress,
    // stale threshold (seconds)
    stale_threshold: u64,
}

#[constructor]
fn constructor(ref self: ContractState, admin: ContractAddress, stale_threshold: u64) {
    self.admin.write(admin);
    self.stale_threshold.write(stale_threshold);
}

// --- Admin: Set Chainlink Feed ---
#[external]
fn set_chainlink_feed(ref self: ContractState, token: felt252, feed: ContractAddress, decimals: u8) {
    let admin = self.admin.read();
    assert(get_caller_address() == admin, 'only_admin');
    self.chainlink_feeds.write(token, feed);
    self.decimals.write(token, decimals);
}

// --- Admin: Set Fallback Price ---
#[external]
fn set_fallback_price(ref self: ContractState, token: felt252, price: u256) {
    let admin = self.admin.read();
    assert(get_caller_address() == admin, 'only_admin');
    self.fallback_prices.write(token, price);
    self.last_update.write(token, get_block_timestamp());
    emit FallbackPriceUpdated(token, price, admin);
}

// --- Internal: Read Chainlink Feed (stub, replace with real call) ---
fn get_chainlink_price(feed: ContractAddress) -> (u256, u8, bool) {
    // TODO: Replace this stub with actual Chainlink oracle call
    // Return (price, decimals, valid)
    (0, 18, false)
}

// --- External: Get Price (with Fallback) ---
#[external]
fn get_price(self: @ContractState, token: felt252) -> (u256, u8, OracleStatus) {
    let feed = self.chainlink_feeds.read(token);
    let (price, decimals, valid) = get_chainlink_price(feed);
    let now = get_block_timestamp();
    let mut status = OracleStatus::Missing;
    let mut final_price = price;
    let mut final_decimals = decimals;

    if valid && price > 0 {
        let last = self.last_update.read(token);
        let threshold = self.stale_threshold.read();
        if now - last <= threshold {
            status = OracleStatus::Ok;
            self.last_price.write(token, price);
            self.last_update.write(token, now);
            emit PriceFeedUpdated(token, price, decimals, 'chainlink');
        } else {
            status = OracleStatus::Stale;
        }
    } else {
        // Fallback to manual price
        let fallback = self.fallback_prices.read(token);
        if fallback > 0 {
            final_price = fallback;
            final_decimals = 18;
            status = OracleStatus::Fallback;
            emit PriceFeedUpdated(token, fallback, 18, 'fallback');
        }
    }
    (final_price, final_decimals, status)
}

// --- Utility: Convert Token Amount to USD ---
#[external]
fn to_usd(self: @ContractState, token: felt252, amount: u256) -> (u256, OracleStatus) {
    let (price, decimals, status) = self.get_price(token);
    if price == 0 {
        return (0, status);
    }
    // Normalize to 18 decimals
    let mut norm_amount = amount;
    if decimals < 18 {
        norm_amount = amount * 10u256.pow(18u8 - decimals);
    } else if decimals > 18 {
        norm_amount = amount / 10u256.pow(decimals - 18u8);
    }
    let usd_value = norm_amount * price / 10u256.pow(18u8);
    emit ConversionPerformed(token, amount, usd_value);
    (usd_value, status)
}

// --- Read-only: Expose Current Exchange Rate ---
#[view]
fn get_exchange_rate(self: @ContractState, token: felt252) -> (u256, u8, OracleStatus) {
    self.get_price(token)
}

// --- Utility: Is Price Stale? ---
#[view]
fn is_stale(self: @ContractState, token: felt252) -> bool {
    let now = get_block_timestamp();
    let last = self.last_update.read(token);
    let threshold = self.stale_threshold.read();
    now - last > threshold
}

// --- Utility: Get Last Update Timestamp ---
#[view]
fn last_update_time(self: @ContractState, token: felt252) -> u64 {
    self.last_update.read(token)
}

// --- Utility: Get Fallback Price ---
#[view]
fn get_fallback_price(self: @ContractState, token: felt252) -> u256 {
    self.fallback_prices.read(token)
}
