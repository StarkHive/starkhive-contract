use starknet::ContractAddress;

#[starknet::interface]
trait IMultisigIntegration<TContractState> {
    fn propose_dispute_action(
        ref self: TContractState,
        dispute_id: u256,
        action_type: u8, // 1 = resolve, 2 = appeal, 3 = penalty
        target: ContractAddress,
        amount: u256
    ) -> u256;
    
    fn approve_dispute_action(ref self: TContractState, proposal_id: u256);
    
    fn execute_dispute_action(ref self: TContractState, proposal_id: u256);
    
    fn get_required_signatures(self: @TContractState) -> u32;
}

#[derive(Drop, Serde, starknet::Store)]
struct DisputeProposal {
    id: u256,
    dispute_id: u256,
    proposer: ContractAddress,
    action_type: u8,
    target: ContractAddress,
    amount: u256,
    approvals: u32,
    executed: bool,
    created_at: u64,
    deadline: u64,
}

#[starknet::contract]
mod MultisigIntegration {
    use super::{IMultisigIntegration, DisputeProposal};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess,
        Map, StoragePathEntry
    };

    #[storage]
    struct Storage {
        dispute_contract: ContractAddress,
        signers: Map<ContractAddress, bool>,
        signer_count: u32,
        required_signatures: u32,
        proposal_counter: u256,
        proposals: Map<u256, DisputeProposal>,
        proposal_approvals: Map<(u256, ContractAddress), bool>,
        proposal_timeout: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ProposalCreated: ProposalCreated,
        ProposalApproved: ProposalApproved,
        ProposalExecuted: ProposalExecuted,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalCreated {
        proposal_id: u256,
        dispute_id: u256,
        proposer: ContractAddress,
        action_type: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalApproved {
        proposal_id: u256,
        approver: ContractAddress,
        total_approvals: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct ProposalExecuted {
        proposal_id: u256,
        executor: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        dispute_contract: ContractAddress,
        initial_signers: Array<ContractAddress>,
        required_signatures: u32,
    ) {
        self.dispute_contract.write(dispute_contract);
        self.required_signatures.write(required_signatures);
        self.proposal_counter.write(0);
        self.proposal_timeout.write(604800); // 7 days

        let mut i = 0;
        loop {
            if i >= initial_signers.len() {
                break;
            }
            self.signers.write(*initial_signers.at(i), true);
            i += 1;
        };
        self.signer_count.write(initial_signers.len());
    }

    #[abi(embed_v0)]
    impl MultisigIntegrationImpl of IMultisigIntegration<ContractState> {
        fn propose_dispute_action(
            ref self: ContractState,
            dispute_id: u256,
            action_type: u8,
            target: ContractAddress,
            amount: u256
        ) -> u256 {
            let caller = get_caller_address();
            assert!(self.signers.read(caller), "Not authorized signer");

            let proposal_id = self.proposal_counter.read() + 1;
            let current_time = get_block_timestamp();

            let proposal = DisputeProposal {
                id: proposal_id,
                dispute_id,
                proposer: caller,
                action_type,
                target,
                amount,
                approvals: 1, // Proposer automatically approves
                executed: false,
                created_at: current_time,
                deadline: current_time + self.proposal_timeout.read(),
            };

            self.proposals.write(proposal_id, proposal);
            self.proposal_approvals.write((proposal_id, caller), true);
            self.proposal_counter.write(proposal_id);

            self.emit(ProposalCreated {
                proposal_id,
                dispute_id,
                proposer: caller,
                action_type,
            });

            proposal_id
        }

        fn approve_dispute_action(ref self: ContractState, proposal_id: u256) {
            let caller = get_caller_address();
            assert!(self.signers.read(caller), "Not authorized signer");

            let mut proposal = self.proposals.read(proposal_id);
            assert!(!proposal.executed, "Proposal already executed");
            assert!(get_block_timestamp() <= proposal.deadline, "Proposal expired");
            assert!(!self.proposal_approvals.read((proposal_id, caller)), "Already approved");

            self.proposal_approvals.write((proposal_id, caller), true);
            proposal.approvals += 1;
            self.proposals.write(proposal_id, proposal);

            self.emit(ProposalApproved {
                proposal_id,
                approver: caller,
                total_approvals: proposal.approvals,
            });
        }

        fn execute_dispute_action(ref self: ContractState, proposal_id: u256) {
            let caller = get_caller_address();
            let mut proposal = self.proposals.read(proposal_id);

            assert!(!proposal.executed, "Proposal already executed");
            assert!(proposal.approvals >= self.required_signatures.read(), "Insufficient approvals");
            assert!(get_block_timestamp() <= proposal.deadline, "Proposal expired");

            proposal.executed = true;
            self.proposals.write(proposal_id, proposal);

            // Execute the dispute action based on action_type
            // This would call the appropriate function on the dispute contract

            self.emit(ProposalExecuted {
                proposal_id,
                executor: caller,
            });
        }

        fn get_required_signatures(self: @ContractState) -> u32 {
            self.required_signatures.read()
        }
    }
}
