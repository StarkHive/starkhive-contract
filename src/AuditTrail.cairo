use starknet::{ContractAddress, get_caller_address, get_block_timestamp};

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub enum ActionType {
    STATECHANGE,
    #[default]
    APPROVAL
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct AuditEntry {
    action_type: ActionType,
    timestamp: u64,
    actor: ContractAddress,
    ipfs_hash: felt252
}

#[starknet::interface]
pub trait IAuditTrail<TContractState> {
    fn log_action(ref self: TContractState, job_id: u64, action_type: u64, ipfs_hash: Option<felt252>);
    fn get_job_audit_logs(self: @TContractState, job_id: u64) -> Array<AuditEntry>;
}

#[starknet::contract]
pub mod AuditTrail {
    use super::{IAuditTrail, ActionType, AuditEntry};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Vec, VecTrait, MutableVecTrait};

    #[storage]
    pub struct Storage {
        audit_entries: Map::<u64, Vec<AuditEntry>>, // Maps a job id to all entries that have to do with it
    }

    #[event]
    #[derive(Copy, Drop, Serde, starknet::Event)]
    pub enum Event {
        ActionLogged: ActionLogged,
    }

    #[derive(Copy, Drop, Serde, starknet::Event)]
    pub struct ActionLogged {
        job_id: u64,
        action_type: ActionType,
        timestamp: u64,
        actor: ContractAddress,
        ipfs_hash: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState){}

    #[abi(embed_v0)]
    impl AuditTrailImpl of IAuditTrail<ContractState> {
        fn log_action(ref self: ContractState, job_id: u64, action_type: u64, ipfs_hash: Option<felt252>) {
            let timestamp = get_block_timestamp();
            let actor = get_caller_address();
            let mut hash = '';

            let type_of_action = self.read_action_type(action_type);

            if ipfs_hash.is_some() {
                hash = ipfs_hash.unwrap();
            }

            let current_entries = self.audit_entries.entry(job_id);
            
            let new_entry = AuditEntry {
                action_type: type_of_action,
                timestamp,
                actor,
                ipfs_hash: hash
            };
            self.audit_entries.entry(job_id).push(new_entry);

            self
                .emit(
                    ActionLogged {
                        job_id,
                        action_type: type_of_action,
                        timestamp,
                        actor,
                        ipfs_hash: hash,
                    }
            )
        }

        fn get_job_audit_logs(self: @ContractState, job_id: u64) -> Array<AuditEntry> {
            let mut job_entries = array![];
            for i in 0..self.audit_entries.entry(job_id).len() {
                job_entries.append(self.audit_entries.entry(job_id).at(i).read());
            }
            job_entries
        }
    }

    #[generate_trait]
    pub impl InternalFunctions of InternalTrait {
        fn read_action_type(ref self: ContractState, action_type: u64) -> ActionType {
            assert(action_type == 1 || action_type == 2 , 'Invalid action type');

            if action_type == 1 {
                return ActionType::STATECHANGE;
            } else {
                return ActionType::APPROVAL;
            }
        }
    }

}