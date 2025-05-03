use core::hash::HashStateTrait;
use core::poseidon::PoseidonTrait;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starkhive_contract::StarkHiveDAO::{
    IStarkHiveDAODispatcher, IStarkHiveDAODispatcherTrait, StarkHiveDAO,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};

fn deploy_contract() -> (ContractAddress, IStarkHiveDAODispatcher) {
    let contract = declare("StarkHiveDAO").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    let dispatcher = IStarkHiveDAODispatcher { contract_address };

    (contract_address, dispatcher)
}

#[test]
fn test_create_proposal() {
    let (contract_address, dispatcher) = deploy_contract();

    let user = contract_address_const::<'user'>();

    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, user);
    let proposal_id = dispatcher
        .create_proposal(
            title: 'proposal1', description_hash: 'description', action_hash: 'action', deadline: 1,
        );
    let expected_event = StarkHiveDAO::Event::ProposalCreation(
        StarkHiveDAO::ProposalCreation {
            proposal_id,
            title: 'proposal1',
            description_hash: 'description',
            action_hash: 'action',
            deadline: 1,
        },
    );

    // Assert that the event was emitted
    spy.assert_emitted(@array![(contract_address, expected_event)]);

    let assert_proposal_id = PoseidonTrait::new()
        .update(user.try_into().unwrap())
        .update('proposal1')
        .update('description')
        .update('action')
        .finalize();

    assert(proposal_id == assert_proposal_id, 'Incorrect proposal_id returned');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Proposal already exists',))]
fn test_create_proposal_existing_proposal() {
    let (contract_address, dispatcher) = deploy_contract();

    let user = contract_address_const::<'user'>();

    start_cheat_caller_address(contract_address, user);
    dispatcher
        .create_proposal(
            title: 'proposal1', description_hash: 'description', action_hash: 'action', deadline: 1,
        );
    dispatcher
        .create_proposal(
            title: 'proposal1', description_hash: 'description', action_hash: 'action', deadline: 1,
        );

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Proposal does not exist',))]
fn test_cast_vote_proposal_does_not_exist() {
    let (contract_address, dispatcher) = deploy_contract();

    let user = contract_address_const::<'user'>();

    start_cheat_caller_address(contract_address, user);

    dispatcher.cast_vote('wrong proposal', true);

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Already voted for this proposal',))]
fn test_cast_vote_proposal_already_voted() {
    let (contract_address, dispatcher) = deploy_contract();

    let user = contract_address_const::<'user'>();

    start_cheat_caller_address(contract_address, user);

    let proposal_id = dispatcher
        .create_proposal(
            title: 'proposal1',
            description_hash: 'description',
            action_hash: 'action',
            deadline: 999999999999,
        );
    dispatcher.cast_vote(proposal_id, true);
    dispatcher.cast_vote(proposal_id, false);

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Voting deadline has passed',))]
fn test_cast_vote_voting_deadline_expired() {
    let (contract_address, dispatcher) = deploy_contract();

    let user = contract_address_const::<'user'>();

    start_cheat_caller_address(contract_address, user);

    let proposal_id = dispatcher
        .create_proposal(
            title: 'proposal1', description_hash: 'description', action_hash: 'action', deadline: 0,
        );
    dispatcher.cast_vote(proposal_id, true);

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_cast_vote() {
    let (contract_address, dispatcher) = deploy_contract();

    let user = contract_address_const::<'user'>();
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, user);

    let proposal_id = dispatcher
        .create_proposal(
            title: 'proposal1',
            description_hash: 'description',
            action_hash: 'action',
            deadline: get_block_timestamp() + 1000,
        );
    dispatcher.cast_vote(proposal_id, true);

    let expected_event = StarkHiveDAO::Event::CastVote(
        StarkHiveDAO::CastVote { proposal_id, vote: true, voter: user },
    );

    // Assert that the event was emitted
    spy.assert_emitted(@array![(contract_address, expected_event)]);

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Proposal does not exist',))]
fn test_execute_action_proposal_does_not_exist() {
    let (contract_address, dispatcher) = deploy_contract();

    let user = contract_address_const::<'user'>();

    start_cheat_caller_address(contract_address, user);

    dispatcher.execute_action('wrong proposal');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('Proposal owner can take action',))]
fn test_execute_action_proposal_owner() {
    let (contract_address, dispatcher) = deploy_contract();

    let user = contract_address_const::<'user'>();
    let non_owner = contract_address_const::<'non_owner'>();

    start_cheat_caller_address(contract_address, user);
    let proposal_id = dispatcher
        .create_proposal(
            title: 'proposal1',
            description_hash: 'description',
            action_hash: 'action',
            deadline: get_block_timestamp() + 1000,
        );

    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, non_owner);
    dispatcher.execute_action(proposal_id);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_execute_action() {
    let (contract_address, dispatcher) = deploy_contract();

    let user = contract_address_const::<'user'>();
    let mut spy = spy_events();

    start_cheat_caller_address(contract_address, user);
    let proposal_id = dispatcher
        .create_proposal(
            title: 'proposal1',
            description_hash: 'description',
            action_hash: 'action',
            deadline: get_block_timestamp() + 1000,
        );
    dispatcher.execute_action(proposal_id);
    let expected_event = StarkHiveDAO::Event::ActionExecution(
        StarkHiveDAO::ActionExecution {
            proposal_id, action_hash: 'action', timestamp: get_block_timestamp(),
        },
    );

    // Assert that the event was emitted
    spy.assert_emitted(@array![(contract_address, expected_event)]);
    stop_cheat_caller_address(contract_address);
}

