use starknet::{ContractAddress, contract_address_const};

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};
use starkhive_contract::AuditTrail::{IAuditTrailDispatcher, IAuditTrailDispatcherTrait};
use starkhive_contract::AuditTrail::ActionType;

fn deploy_contract() -> (ContractAddress, IAuditTrailDispatcher) {
    let contract = declare("AuditTrail").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    let dispatcher = IAuditTrailDispatcher { contract_address };
    
    (contract_address, dispatcher)
}

#[test]
fn test_contract() {
    let (contract_address, dispatcher) = deploy_contract();

    let user = contract_address_const::<'user'>();

    start_cheat_caller_address(contract_address, user);
    dispatcher.log_action(1, 1, Option::None);
    stop_cheat_caller_address(contract_address);

    let audit_logs = dispatcher.get_job_audit_logs(1);
    let audit_log = audit_logs.at(0);

    assert(audit_log.action_type == @ActionType::STATECHANGE, 'Error in creating audit log');
    assert(audit_log.actor == @user, 'Error in processing user')
}