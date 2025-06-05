#[starknet::contract]
pub mod Dispute {
    use starkhive_contract::base::types::{
        ArbitratorInfo, Dispute, DisputeStatus, Evidence, VoteInfo,
    };
    use starkhive_contract::interfaces::IDispute::IDispute;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{
        ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
    };

    // --------------- Storage -----------------
    #[storage]
    struct Storage {
        disputes: Map<u256, Dispute>, // dispute_id -> Dispute
        dispute_counter: u256,
        evidence_counter: Map<u256, u256>, // dispute_id -> next evidence id
        evidences: Map<(u256, u256), Evidence>, // (dispute_id, evidence_id) -> Evidence
        votes: Map<(u256, ContractAddress), VoteInfo>, // (dispute_id, arbitrator) -> VoteInfo
        arbitrators: Map<ContractAddress, ArbitratorInfo>, // reputation mapping
        multi_sig: ContractAddress // multi-sig wallet that can penalise
    }

    // --------------- Events ------------------
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        DisputeInitiated: DisputeInitiated,
        EvidenceSubmitted: EvidenceSubmitted,
        Voted: Voted,
        DisputeResolved: DisputeResolved,
        DisputeAppealed: DisputeAppealed,
        FalseDisputePenalised: FalseDisputePenalised,
        ArbitratorReputationUpdated: ArbitratorReputationUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DisputeInitiated {
        #[key]
        pub dispute_id: u256,
        pub job_id: u256,
        pub claimant: ContractAddress,
        pub respondent: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EvidenceSubmitted {
        #[key]
        pub dispute_id: u256,
        pub evidence_id: u256,
        pub submitter: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Voted {
        #[key]
        pub dispute_id: u256,
        pub arbitrator: ContractAddress,
        pub support: bool,
        pub weight: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DisputeResolved {
        #[key]
        pub dispute_id: u256,
        pub winner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DisputeAppealed {
        #[key]
        pub dispute_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FalseDisputePenalised {
        #[key]
        pub dispute_id: u256,
        pub claimant: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ArbitratorReputationUpdated {
        #[key]
        pub arbitrator: ContractAddress,
        pub new_rep: u256,
    }


    // --------------- Impl --------------------
    #[abi(embed_v0)]
    impl DisputeImpl of IDispute<ContractState> {
        // Multi-sig init (called once)
        fn init(ref self: ContractState, multi_sig: ContractAddress) {
            let zero: ContractAddress = contract_address_const::<'0x0'>();
            let current: ContractAddress = self.multi_sig.read();
            assert(current == zero, 'only_multisig');
            self.multi_sig.write(multi_sig);
        }

        fn initiate_dispute(
            ref self: ContractState,
            job_id: u256,
            claimant: ContractAddress,
            respondent: ContractAddress,
        ) -> u256 {
            let caller = get_caller_address();
            assert(caller == claimant, 'only_claimant');

            let dispute_id = self.dispute_counter.read() + 1;
            let now = get_block_timestamp();
            let voting_period: u64 = 3 * 24 * 60 * 60; // 3 days

            let dispute = Dispute {
                dispute_id,
                job_id,
                claimant,
                respondent,
                status: DisputeStatus::Open,
                voting_deadline: now + voting_period,
                created_at: now,
            };
            self.disputes.write(dispute_id, dispute);
            self.dispute_counter.write(dispute_id);

            self.emit(DisputeInitiated { dispute_id, job_id, claimant, respondent });
            dispute_id
        }

        fn submit_evidence(ref self: ContractState, dispute_id: u256, data: ByteArray) {
            let caller = get_caller_address();
            let dispute = self.disputes.read(dispute_id);
            assert(
                dispute.status == DisputeStatus::Open || dispute.status == DisputeStatus::Voting,
                'wrong_status',
            );

            let next_id = self.evidence_counter.read(dispute_id) + 1;
            let now = get_block_timestamp();
            let ev = Evidence {
                dispute_id, evidence_id: next_id, submitter: caller, data, submitted_at: now,
            };
            self.evidences.write((dispute_id, next_id), ev);
            self.evidence_counter.write(dispute_id, next_id);
            self.emit(EvidenceSubmitted { dispute_id, evidence_id: next_id, submitter: caller });
        }

        fn vote(ref self: ContractState, dispute_id: u256, support: bool) {
            let caller = get_caller_address();
            let mut dispute = self.disputes.read(dispute_id);
            let now = get_block_timestamp();
            assert(now < dispute.voting_deadline, 'voting_closed');

            // ensure only arbitrators (non-party) vote
            let claimant = dispute.clone().claimant;
            let respondent = dispute.clone().respondent;
            assert(caller != claimant && caller != respondent, 'party_cannot_vote');

            let mut vote_info = self.votes.read((dispute_id, caller));
            assert(vote_info.dispute_id == 0, 'already_voted');

            // reputation weight
            let arbitrator_info = self.arbitrators.read(caller);
            let weight: u256 = 1_u256;
            let vi = VoteInfo {
                dispute_id, arbitrator: caller, support, weight, submitted_at: now,
            };
            self.votes.write((dispute_id, caller), vi);

            // Work around Cairo move semantics: move `dispute` once into a new mutable var,
            // then inspect & potentially mutate it before writing back.
            let mut updated_dispute = dispute;
            if updated_dispute.status == DisputeStatus::Open {
                updated_dispute.status = DisputeStatus::Voting;
            }
            self.disputes.write(dispute_id, updated_dispute);

            self.emit(Voted { dispute_id, arbitrator: caller, support, weight });
        }

        fn resolve_dispute(ref self: ContractState, dispute_id: u256) {
            let mut dispute = self.disputes.read(dispute_id);
            let now = get_block_timestamp();
            assert(now >= dispute.voting_deadline, 'too_early');
            assert(
                dispute.status == DisputeStatus::Voting || dispute.status == DisputeStatus::Open,
                'wrong_status',
            );

            // Simplified: first implementation just awards claimant.
            let winner = dispute.clone().claimant;
            self.emit(DisputeResolved { dispute_id, winner });
            dispute.status = DisputeStatus::Resolved;
            self.disputes.write(dispute_id, dispute);
        }

        fn appeal_dispute(ref self: ContractState, dispute_id: u256) {
            let caller = get_caller_address();
            let mut dispute = self.disputes.read(dispute_id);
            assert(dispute.status == DisputeStatus::Resolved, 'not_resolved');
            assert(
                caller == dispute.clone().claimant || caller == dispute.clone().respondent,
                'only_party',
            );
            dispute.status = DisputeStatus::Appealed;
            dispute.voting_deadline = get_block_timestamp() + 2 * 24 * 60 * 60; // 2 days
            self.disputes.write(dispute_id, dispute);
            self.emit(DisputeAppealed { dispute_id });
        }

        fn penalise_false_dispute(ref self: ContractState, dispute_id: u256) {
            let caller = get_caller_address();
            let multi_sig = self.multi_sig.read();
            assert(caller == multi_sig, 'only_multisig');

            let dispute = self.disputes.read(dispute_id);
            self.emit(FalseDisputePenalised { dispute_id, claimant: dispute.clone().claimant });
            // penalty logic left minimal for demo.
        }

        fn get_dispute(self: @ContractState, dispute_id: u256) -> Dispute {
            let d = self.disputes.read(dispute_id);
            d
        }

        fn get_vote(
            self: @ContractState, dispute_id: u256, arbitrator: ContractAddress,
        ) -> VoteInfo {
            let v = self.votes.read((dispute_id, arbitrator));
            v
        }

        fn get_arbitrator(self: @ContractState, address: ContractAddress) -> ArbitratorInfo {
            let info = self.arbitrators.read(address);
            info
        }
    }
}
