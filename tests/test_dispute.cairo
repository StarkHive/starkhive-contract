use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_block_timestamp, cheat_caller_address,
    declare, start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global,
    stop_cheat_caller_address,
};
use starkhive_contract::base::types::DisputeStatus;
use starkhive_contract::interfaces::IDispute::{IDisputeDispatcher, IDisputeDispatcherTrait};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};


fn setup() -> ContractAddress {
    let declare_result = declare("Dispute");
    assert(declare_result.is_ok(), 'Contract declaration failed');

    let contract_class = declare_result.unwrap().contract_class();
    let mut calldata = array![];

    let deploy_result = contract_class.deploy(@calldata);
    assert(deploy_result.is_ok(), 'Contract deployment failed');

    let (contract_address, _) = deploy_result.unwrap();

    contract_address
}

#[test]
fn test_initiate_dispute() {
    let contract_address = setup();
    let dispatcher = IDisputeDispatcher { contract_address };

    let claimant: ContractAddress = contract_address_const::<'claimant'>();
    let respondent: ContractAddress = contract_address_const::<'respondent'>();

    cheat_caller_address(contract_address, claimant, CheatSpan::Indefinite);

    let dispute_id = dispatcher.initiate_dispute(1, claimant, respondent);

    stop_cheat_caller_address(contract_address);

    let dispute = dispatcher.get_dispute(dispute_id);
    assert(dispute.dispute_id == dispute_id, 'wrong id');
    assert(dispute.job_id == 1, 'wrong job id');
    assert(dispute.claimant == claimant, 'wrong claimant');
    assert(dispute.respondent == respondent, 'wrong respondent');
    assert(dispute.status == DisputeStatus::Open, 'status not open');
}

#[test]
fn test_first_vote_changes_status_to_voting() {
    let contract_address = setup();
    let dispatcher = IDisputeDispatcher { contract_address };

    let claimant: ContractAddress = contract_address_const::<'claimant'>();
    let respondent: ContractAddress = contract_address_const::<'respondent'>();
    let arbitrator: ContractAddress = contract_address_const::<'arb1'>();

    cheat_caller_address(contract_address, claimant, CheatSpan::Indefinite);
    let dispute_id = dispatcher.initiate_dispute(1, claimant, respondent);
    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, arbitrator, CheatSpan::Indefinite);
    dispatcher.vote(dispute_id, true);
    stop_cheat_caller_address(contract_address);

    let dispute = dispatcher.get_dispute(dispute_id);
    assert(dispute.status == DisputeStatus::Voting, 'should be voting first vote');
}


#[test]
#[should_panic(expected: ('party_cannot_vote',))]
fn test_party_cannot_vote() {
    let contract_address = setup();
    let dispatcher = IDisputeDispatcher { contract_address };

    let claimant: ContractAddress = contract_address_const::<'claimant'>();
    let respondent: ContractAddress = contract_address_const::<'respondent'>();

    cheat_caller_address(contract_address, claimant, CheatSpan::Indefinite);
    let dispute_id = dispatcher.initiate_dispute(1, claimant, respondent);
    dispatcher.vote(dispute_id, true);
}

#[test]
#[should_panic(expected: ('already_voted',))]
fn test_arbitrator_cannot_double_vote() {
    let contract_address = setup();
    let dispatcher = IDisputeDispatcher { contract_address };

    let claimant: ContractAddress = contract_address_const::<'claimant'>();
    let respondent: ContractAddress = contract_address_const::<'respondent'>();
    let arbitrator: ContractAddress = contract_address_const::<'arb1'>();

    cheat_caller_address(contract_address, claimant, CheatSpan::Indefinite);
    let dispute_id = dispatcher.initiate_dispute(1, claimant, respondent);
    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, arbitrator, CheatSpan::Indefinite);
    dispatcher.vote(dispute_id, true);

    dispatcher.vote(dispute_id, false);
}


#[test]
#[should_panic(expected: ('only_multisig',))]
fn test_init_only_once() {
    let contract_address = setup();
    let dispatcher = IDisputeDispatcher { contract_address };

    let multisig: ContractAddress = contract_address_const::<'msig'>();

    dispatcher.init(multisig);

    dispatcher.init(multisig);
}

#[test]
fn test_submit_evidence_success() {
    let contract_address = setup();
    let dispatcher = IDisputeDispatcher { contract_address };

    let claimant: ContractAddress = contract_address_const::<'claimant'>();
    let respondent: ContractAddress = contract_address_const::<'respondent'>();

    cheat_caller_address(contract_address, claimant, CheatSpan::Indefinite);
    let dispute_id = dispatcher.initiate_dispute(1, claimant, respondent);
}


#[test]
fn test_resolve_dispute_after_deadline() {
    let contract_address = setup();
    let dispatcher = IDisputeDispatcher { contract_address };

    let claimant: ContractAddress = contract_address_const::<'claimant'>();
    let respondent: ContractAddress = contract_address_const::<'respondent'>();

    cheat_caller_address(contract_address, claimant, CheatSpan::Indefinite);
    let dispute_id = dispatcher.initiate_dispute(1, claimant, respondent);
    stop_cheat_caller_address(contract_address);

    let now = get_block_timestamp();
    start_cheat_block_timestamp_global(now + 4 * 24 * 60 * 60);

    dispatcher.resolve_dispute(dispute_id);

    stop_cheat_block_timestamp_global();

    let dispute = dispatcher.get_dispute(dispute_id);
    assert(dispute.status == DisputeStatus::Resolved, 'should be resolved');
}

#[test]
#[should_panic(expected: ('too_early',))]
fn test_resolve_dispute_too_early() {
    let contract_address = setup();
    let dispatcher = IDisputeDispatcher { contract_address };

    let claimant: ContractAddress = contract_address_const::<'claimant'>();
    let respondent: ContractAddress = contract_address_const::<'respondent'>();

    cheat_caller_address(contract_address, claimant, CheatSpan::Indefinite);
    let dispute_id = dispatcher.initiate_dispute(1, claimant, respondent);
    stop_cheat_caller_address(contract_address);

    // Immediately attempt to resolve – should revert
    dispatcher.resolve_dispute(dispute_id);
}

// --------------------------------------------------
// Voting closed after deadline
#[test]
#[should_panic(expected: ('voting_closed',))]
fn test_vote_after_deadline() {
    let contract_address = setup();
    let dispatcher = IDisputeDispatcher { contract_address };

    let claimant: ContractAddress = contract_address_const::<'claimant'>();
    let respondent: ContractAddress = contract_address_const::<'respondent'>();
    let arbitrator: ContractAddress = contract_address_const::<'arb1'>();

    cheat_caller_address(contract_address, claimant, CheatSpan::Indefinite);
    let dispute_id = dispatcher.initiate_dispute(1, claimant, respondent);
    stop_cheat_caller_address(contract_address);

    let now = get_block_timestamp();
    start_cheat_block_timestamp_global(now + 4 * 24 * 60 * 60);

    cheat_caller_address(contract_address, arbitrator, CheatSpan::Indefinite);
    dispatcher.vote(dispute_id, true);
}

#[test]
fn test_appeal_dispute_success() {
    let contract_address = setup();
    let dispatcher = IDisputeDispatcher { contract_address };

    let claimant: ContractAddress = contract_address_const::<'claimant'>();
    let respondent: ContractAddress = contract_address_const::<'respondent'>();

    cheat_caller_address(contract_address, claimant, CheatSpan::Indefinite);
    let dispute_id = dispatcher.initiate_dispute(1, claimant, respondent);
    stop_cheat_caller_address(contract_address);

    let now = get_block_timestamp();
    start_cheat_block_timestamp_global(now + 4 * 24 * 60 * 60);
    dispatcher.resolve_dispute(dispute_id);
    stop_cheat_block_timestamp_global();

    cheat_caller_address(contract_address, respondent, CheatSpan::Indefinite);
    dispatcher.appeal_dispute(dispute_id);
    stop_cheat_caller_address(contract_address);

    let dispute = dispatcher.get_dispute(dispute_id);
    assert(dispute.status == DisputeStatus::Appealed, 'should be appealed');
}

#[test]
#[should_panic(expected: ('not_resolved',))]
fn test_appeal_dispute_not_resolved() {
    let contract_address = setup();
    let dispatcher = IDisputeDispatcher { contract_address };

    let claimant: ContractAddress = contract_address_const::<'claimant'>();
    let respondent: ContractAddress = contract_address_const::<'respondent'>();

    cheat_caller_address(contract_address, claimant, CheatSpan::Indefinite);
    let dispute_id = dispatcher.initiate_dispute(1, claimant, respondent);

    dispatcher.appeal_dispute(dispute_id);
}

#[test]
#[should_panic(expected: ('only_multisig',))]
fn test_penalise_false_dispute_wrong_caller() {
    let contract_address = setup();
    let dispatcher = IDisputeDispatcher { contract_address };

    let msig: ContractAddress = contract_address_const::<'msig'>();
    dispatcher.init(msig);

    let claimant: ContractAddress = contract_address_const::<'claimant'>();
    cheat_caller_address(contract_address, claimant, CheatSpan::Indefinite);
    dispatcher.penalise_false_dispute(1);
}
