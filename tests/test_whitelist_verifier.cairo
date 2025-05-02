use starkhive_contract::WhitelistVerifier::{ IWhitelistVerifierDispatcher, IWhitelistVerifierDispatcherTrait};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};
use starknet::{ContractAddress, contract_address_const};  

fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

fn USER() -> ContractAddress {
    contract_address_const::<'USER'>()
}

fn deploy_whitelist_verifier() -> (IWhitelistVerifierDispatcher, ContractAddress) {
    let contract = declare("WhitelistVerifier").unwrap().contract_class();
    let constructor_calldata = array![OWNER().into()];
    
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();

    let dispatcher = IWhitelistVerifierDispatcher { contract_address };

    (dispatcher, contract_address)
}

#[test]
fn test_add_to_whitelist() {
    let (dispatcher, contract_address) = deploy_whitelist_verifier();

    start_cheat_caller_address(contract_address, OWNER());
    dispatcher.add_to_whitelist(USER());
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.is_whitelisted(USER()));
}

#[test]
fn test_remove_from_whitelist() {
    let (dispatcher, contract_address) = deploy_whitelist_verifier();

    start_cheat_caller_address(contract_address, OWNER());
    dispatcher.add_to_whitelist(USER());
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.is_whitelisted(USER()));

    start_cheat_caller_address(contract_address, OWNER());
    dispatcher.remove_from_whitelist(USER());
    stop_cheat_caller_address(contract_address);

    assert!(!dispatcher.is_whitelisted(USER()));
}

#[test]
fn test_grant_admin_role() {
    let (dispatcher, contract_address) = deploy_whitelist_verifier();
    start_cheat_caller_address(contract_address, OWNER());
    dispatcher.grant_admin_role(USER());
    stop_cheat_caller_address(contract_address);

    // User should be able to add to whitelist after granting admin role
    start_cheat_caller_address(contract_address, USER());
    dispatcher.add_to_whitelist(OWNER());
    stop_cheat_caller_address(contract_address);

    assert!(dispatcher.is_whitelisted(OWNER()));
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_only_admin_can_grant_admin_role() {
    let (dispatcher, contract_address) = deploy_whitelist_verifier();
    start_cheat_caller_address(contract_address, USER());
    dispatcher.grant_admin_role(USER());
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_only_admin_can_add_to_whitelist() {
    let (dispatcher, contract_address) = deploy_whitelist_verifier();
    start_cheat_caller_address(contract_address, USER());
    dispatcher.add_to_whitelist(OWNER());
}

#[test]
#[should_panic(expected: 'Caller is missing role')]
fn test_only_admin_can_remove_from_whitelist() {
    let (dispatcher, contract_address) = deploy_whitelist_verifier();
    start_cheat_caller_address(contract_address, USER());
    dispatcher.remove_from_whitelist(OWNER());
}