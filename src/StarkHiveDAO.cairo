/// Interface representing DAO proposal and voting system actions
#[starknet::interface]
pub trait IStarkHiveDAO<TContractState> {
    /// Create a proposal
    fn create_proposal(
        ref self: TContractState,
        title: felt252,
        description_hash: felt252,
        action_hash: felt252,
        deadline: u64,
    ) -> felt252;
    /// Cast a vote
    fn cast_vote(ref self: TContractState, proposal_id: felt252, vote: bool);
    /// Execute action in proposal
    fn execute_action(ref self: TContractState, proposal_id: felt252);
}

#[starknet::contract]
pub mod StarkHiveDAO {
    use core::hash::{HashStateExTrait, HashStateTrait};
    use core::poseidon::{PoseidonTrait, poseidon_hash_span};
    use starknet::storage::{
        Map, StorageMapWriteAccess, StoragePathEntry, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

    #[derive(Drop, Serde, starknet::Store)]
    struct Proposal {
        owner: ContractAddress,
        title: felt252,
        description_hash: felt252,
        action_hash: felt252,
        deadline: u64,
        positive_votes: u64,
        negative_votes: u64,
    }

    #[storage]
    struct Storage {
        proposals: Map<felt252, Proposal>,
        proposal_exists: Map<felt252, bool>,
        votes_casted: Map<ContractAddress, Map<felt252, bool>>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ProposalCreation: ProposalCreation,
        CastVote: CastVote,
        ActionExecution: ActionExecution,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProposalCreation {
        proposal_id: felt252,
        title: felt252,
        description_hash: felt252,
        action_hash: felt252,
        deadline: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CastVote {
        voter: ContractAddress,
        proposal_id: felt252,
        vote: bool
    }

    #[derive(Drop, starknet::Event)]
    pub struct ActionExecution {
        proposal_id: felt252,
        action_hash: felt252,
        timestamp: u64
    }

    #[abi(embed_v0)]
    impl IStarkHiveDAOImpl of super::IStarkHiveDAO<ContractState> {
        fn create_proposal(
            ref self: ContractState,
            title: felt252,
            description_hash: felt252,
            action_hash: felt252,
            deadline: u64,
        ) -> felt252 {
            let mut proposal_id = PoseidonTrait::new()
                .update(get_caller_address().try_into().unwrap())
                .update(title)
                .update(description_hash)
                .update(action_hash)
                .finalize();

            assert(!self.proposal_exists.entry(proposal_id).read(), 'Proposal already exists');

            let mut proposal = self.proposals.entry(proposal_id);
            proposal.owner.write(get_caller_address());
            proposal.title.write(title);
            proposal.description_hash.write(description_hash);
            proposal.action_hash.write(action_hash);
            proposal.deadline.write(deadline);
            proposal.positive_votes.write(0);
            proposal.negative_votes.write(0);

            self.proposal_exists.entry(proposal_id).write(true);

            self.emit(ProposalCreation {
                proposal_id,
                title,
                description_hash,
                action_hash,
                deadline,
            });

            proposal_id
        }

        fn cast_vote(ref self: ContractState, proposal_id: felt252, vote: bool) {
            assert(self.proposal_exists.entry(proposal_id).read(), 'Proposal does not exist');
            let voter_address = get_caller_address();
            assert(!self.votes_casted.entry(voter_address).entry(proposal_id).read(), 'Already voted for this proposal');

            let timestamp = get_block_timestamp();
            let proposal_deadline = self.proposals.entry(proposal_id).deadline.read();
            assert(timestamp < proposal_deadline, 'Voting deadline has passed');

            self.votes_casted.entry(voter_address).entry(proposal_id).write(true);
            let mut proposal = self.proposals.entry(proposal_id);
            if vote {
                proposal.positive_votes.write(proposal.positive_votes.read() + 1);
            } else {
                proposal.negative_votes.write(proposal.negative_votes.read() + 1);
            }

            self.emit(CastVote {
                voter: voter_address,
                proposal_id,
                vote
            })
        }

        fn execute_action(ref self: ContractState, proposal_id: felt252) {
            assert(self.proposal_exists.entry(proposal_id).read(), 'Proposal does not exist');
            let proposal_owner = self.proposals.entry(proposal_id).owner.read();
            assert(get_caller_address() == proposal_owner, 'Proposal owner can take action');

            self.emit(ActionExecution {
                proposal_id,
                action_hash: self.proposals.entry(proposal_id).action_hash.read(),
                timestamp: get_block_timestamp()
            })
        }
    }
}
