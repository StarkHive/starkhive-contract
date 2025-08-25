use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::get_block_timestamp;

#[starknet::interface]
trait IDisputeResolution<TContractState> {
    fn initiate_dispute(
        ref self: TContractState,
        escrow_id: u256,
        disputed_amount: u256,
        evidence_hash: felt252,
        description: felt252
    ) -> u256;
    
    fn submit_evidence(
        ref self: TContractState,
        dispute_id: u256,
        evidence_hash: felt252,
        evidence_type: u8
    );
    
    fn select_arbitrators(
        ref self: TContractState,
        dispute_id: u256,
        arbitrator_count: u8
    );
    
    fn cast_vote(
        ref self: TContractState,
        dispute_id: u256,
        vote: u8, // 0 = reject, 1 = approve, 2 = partial
        reasoning: felt252
    );
    
    fn execute_resolution(ref self: TContractState, dispute_id: u256);
    
    fn initiate_appeal(
        ref self: TContractState,
        dispute_id: u256,
        appeal_evidence: felt252
    ) -> u256;
    
    fn add_arbitrator(
        ref self: TContractState,
        arbitrator: ContractAddress,
        reputation_score: u256
    );
    
    fn get_dispute_details(self: @TContractState, dispute_id: u256) -> DisputeInfo;
}

#[derive(Drop, Serde, starknet::Store)]
struct DisputeInfo {
    id: u256,
    initiator: ContractAddress,
    respondent: ContractAddress,
    escrow_id: u256,
    disputed_amount: u256,
    status: DisputeStatus,
    created_at: u64,
    voting_deadline: u64,
    evidence_count: u32,
    arbitrator_votes: u32,
    total_arbitrators: u32,
    resolution: DisputeResolution,
    appeal_count: u8,
}

#[derive(Drop, Serde, starknet::Store)]
enum DisputeStatus {
    Initiated,
    ArbitratorsSelected,
    EvidenceSubmission,
    Voting,
    Resolved,
    Appealed,
    Finalized,
}

#[derive(Drop, Serde, starknet::Store)]
enum DisputeResolution {
    Pending,
    ApproveInitiator,
    ApproveRespondent,
    PartialResolution: u256, // percentage to initiator
}

#[derive(Drop, Serde, starknet::Store)]
struct Evidence {
    submitter: ContractAddress,
    evidence_hash: felt252,
    evidence_type: u8, // 1 = document, 2 = transaction, 3 = witness
    timestamp: u64,
}

#[derive(Drop, Serde, starknet::Store)]
struct Arbitrator {
    address: ContractAddress,
    reputation_score: u256,
    total_cases: u32,
    successful_cases: u32,
    is_active: bool,
}

#[derive(Drop, Serde, starknet::Store)]
struct Vote {
    arbitrator: ContractAddress,
    vote: u8,
    weight: u256,
    reasoning: felt252,
    timestamp: u64,
}

#[starknet::contract]
mod DisputeResolution {
    use super::{
        IDisputeResolution, DisputeInfo, DisputeStatus, DisputeResolution as Resolution,
        Evidence, Arbitrator, Vote
    };
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess,
        Map, StoragePathEntry
    };

    #[storage]
    struct Storage {
        owner: ContractAddress,
        dispute_counter: u256,
        disputes: Map<u256, DisputeInfo>,
        dispute_evidence: Map<(u256, u32), Evidence>,
        arbitrators: Map<ContractAddress, Arbitrator>,
        arbitrator_assignments: Map<(u256, u32), ContractAddress>,
        votes: Map<(u256, ContractAddress), Vote>,
        escrow_contract: ContractAddress,
        multisig_contract: ContractAddress,
        min_arbitrators: u8,
        max_arbitrators: u8,
        voting_period: u64, // in seconds
        appeal_period: u64,
        penalty_amount: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DisputeInitiated: DisputeInitiated,
        EvidenceSubmitted: EvidenceSubmitted,
        ArbitratorsSelected: ArbitratorsSelected,
        VoteCast: VoteCast,
        DisputeResolved: DisputeResolved,
        AppealInitiated: AppealInitiated,
        PenaltyApplied: PenaltyApplied,
    }

    #[derive(Drop, starknet::Event)]
    struct DisputeInitiated {
        dispute_id: u256,
        initiator: ContractAddress,
        escrow_id: u256,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct EvidenceSubmitted {
        dispute_id: u256,
        submitter: ContractAddress,
        evidence_hash: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct ArbitratorsSelected {
        dispute_id: u256,
        arbitrator_count: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct VoteCast {
        dispute_id: u256,
        arbitrator: ContractAddress,
        vote: u8,
        weight: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct DisputeResolved {
        dispute_id: u256,
        resolution: u8,
        payout_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct AppealInitiated {
        dispute_id: u256,
        appellant: ContractAddress,
        appeal_id: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct PenaltyApplied {
        dispute_id: u256,
        penalized_party: ContractAddress,
        penalty_amount: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        escrow_contract: ContractAddress,
        multisig_contract: ContractAddress,
    ) {
        self.owner.write(owner);
        self.escrow_contract.write(escrow_contract);
        self.multisig_contract.write(multisig_contract);
        self.dispute_counter.write(0);
        self.min_arbitrators.write(3);
        self.max_arbitrators.write(7);
        self.voting_period.write(604800); // 7 days
        self.appeal_period.write(259200); // 3 days
        self.penalty_amount.write(1000000000000000000); // 1 token
    }

    #[abi(embed_v0)]
    impl DisputeResolutionImpl of IDisputeResolution<ContractState> {
        fn initiate_dispute(
            ref self: ContractState,
            escrow_id: u256,
            disputed_amount: u256,
            evidence_hash: felt252,
            description: felt252
        ) -> u256 {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let dispute_id = self.dispute_counter.read() + 1;
            
            // Verify escrow exists and caller is authorized
            // This would integrate with the escrow contract
            
            let dispute = DisputeInfo {
                id: dispute_id,
                initiator: caller,
                respondent: ContractAddress::try_from(0).unwrap(), // To be set from escrow
                escrow_id,
                disputed_amount,
                status: DisputeStatus::Initiated,
                created_at: current_time,
                voting_deadline: 0,
                evidence_count: 1,
                arbitrator_votes: 0,
                total_arbitrators: 0,
                resolution: Resolution::Pending,
                appeal_count: 0,
            };

            self.disputes.write(dispute_id, dispute);
            self.dispute_counter.write(dispute_id);

            // Submit initial evidence
            let initial_evidence = Evidence {
                submitter: caller,
                evidence_hash,
                evidence_type: 1, // document
                timestamp: current_time,
            };
            self.dispute_evidence.write((dispute_id, 0), initial_evidence);

            self.emit(DisputeInitiated {
                dispute_id,
                initiator: caller,
                escrow_id,
                amount: disputed_amount,
            });

            dispute_id
        }

        fn submit_evidence(
            ref self: ContractState,
            dispute_id: u256,
            evidence_hash: felt252,
            evidence_type: u8
        ) {
            let caller = get_caller_address();
            let mut dispute = self.disputes.read(dispute_id);
            
            assert!(
                dispute.status == DisputeStatus::Initiated || 
                dispute.status == DisputeStatus::EvidenceSubmission,
                "Invalid dispute status for evidence submission"
            );

            let evidence = Evidence {
                submitter: caller,
                evidence_hash,
                evidence_type,
                timestamp: get_block_timestamp(),
            };

            self.dispute_evidence.write((dispute_id, dispute.evidence_count), evidence);
            dispute.evidence_count += 1;
            dispute.status = DisputeStatus::EvidenceSubmission;
            
            self.disputes.write(dispute_id, dispute);

            self.emit(EvidenceSubmitted {
                dispute_id,
                submitter: caller,
                evidence_hash,
            });
        }

        fn select_arbitrators(
            ref self: ContractState,
            dispute_id: u256,
            arbitrator_count: u8
        ) {
            let caller = get_caller_address();
            let mut dispute = self.disputes.read(dispute_id);
            
            assert!(caller == dispute.initiator, "Only initiator can select arbitrators");
            assert!(
                arbitrator_count >= self.min_arbitrators.read() && 
                arbitrator_count <= self.max_arbitrators.read(),
                "Invalid arbitrator count"
            );

            // Implement arbitrator selection logic based on reputation
            // This is a simplified version - in practice, you'd want more sophisticated selection
            
            dispute.total_arbitrators = arbitrator_count.into();
            dispute.status = DisputeStatus::ArbitratorsSelected;
            dispute.voting_deadline = get_block_timestamp() + self.voting_period.read();
            
            self.disputes.write(dispute_id, dispute);

            self.emit(ArbitratorsSelected {
                dispute_id,
                arbitrator_count,
            });
        }

        fn cast_vote(
            ref self: ContractState,
            dispute_id: u256,
            vote: u8,
            reasoning: felt252
        ) {
            let caller = get_caller_address();
            let arbitrator = self.arbitrators.read(caller);
            let dispute = self.disputes.read(dispute_id);
            
            assert!(arbitrator.is_active, "Arbitrator not active");
            assert!(dispute.status == DisputeStatus::Voting, "Not in voting phase");
            assert!(get_block_timestamp() <= dispute.voting_deadline, "Voting period expired");
            assert!(vote <= 2, "Invalid vote option");

            // Calculate vote weight based on reputation
            let weight = self._calculate_vote_weight(arbitrator.reputation_score);

            let vote_record = Vote {
                arbitrator: caller,
                vote,
                weight,
                reasoning,
                timestamp: get_block_timestamp(),
            };

            self.votes.write((dispute_id, caller), vote_record);

            self.emit(VoteCast {
                dispute_id,
                arbitrator: caller,
                vote,
                weight,
            });
        }

        fn execute_resolution(ref self: ContractState, dispute_id: u256) {
            let mut dispute = self.disputes.read(dispute_id);
            
            assert!(
                dispute.status == DisputeStatus::Voting,
                "Dispute not ready for resolution"
            );
            assert!(
                get_block_timestamp() > dispute.voting_deadline,
                "Voting period not expired"
            );

            // Calculate voting results
            let (resolution, payout_amount) = self._calculate_resolution(dispute_id);
            
            dispute.resolution = resolution;
            dispute.status = DisputeStatus::Resolved;
            
            self.disputes.write(dispute_id, dispute);

            // Execute payout through escrow contract
            // This would call the escrow contract to release funds

            self.emit(DisputeResolved {
                dispute_id,
                resolution: match resolution {
                    Resolution::ApproveInitiator => 1,
                    Resolution::ApproveRespondent => 2,
                    Resolution::PartialResolution(_) => 3,
                    _ => 0,
                },
                payout_amount,
            });
        }

        fn initiate_appeal(
            ref self: ContractState,
            dispute_id: u256,
            appeal_evidence: felt252
        ) -> u256 {
            let caller = get_caller_address();
            let mut dispute = self.disputes.read(dispute_id);
            
            assert!(dispute.status == DisputeStatus::Resolved, "Dispute not resolved");
            assert!(dispute.appeal_count < 2, "Maximum appeals reached");
            assert!(
                get_block_timestamp() <= dispute.voting_deadline + self.appeal_period.read(),
                "Appeal period expired"
            );

            dispute.appeal_count += 1;
            dispute.status = DisputeStatus::Appealed;
            
            self.disputes.write(dispute_id, dispute);

            let appeal_id = dispute_id * 1000 + dispute.appeal_count.into();

            self.emit(AppealInitiated {
                dispute_id,
                appellant: caller,
                appeal_id,
            });

            appeal_id
        }

        fn add_arbitrator(
            ref self: ContractState,
            arbitrator: ContractAddress,
            reputation_score: u256
        ) {
            let caller = get_caller_address();
            assert!(caller == self.owner.read(), "Only owner can add arbitrators");

            let arbitrator_info = Arbitrator {
                address: arbitrator,
                reputation_score,
                total_cases: 0,
                successful_cases: 0,
                is_active: true,
            };

            self.arbitrators.write(arbitrator, arbitrator_info);
        }

        fn get_dispute_details(self: @ContractState, dispute_id: u256) -> DisputeInfo {
            self.disputes.read(dispute_id)
        }
    }
