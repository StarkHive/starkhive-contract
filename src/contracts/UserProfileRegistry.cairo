use starkhive_contract::base::types::{Profile, WorkEntries};
use starknet::storage::{
    Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp, get_caller_address};

// --------------- Storage -----------------
#[storage]
struct Storage {
    profiles: Map<ContractAddress, Profile>,
    portfolio_links: Map<(ContractAddress, u256), felt252>,
    portfolio_count: Map<ContractAddress, u256>,
    skills: Map<(ContractAddress, u256), felt252>,
    skill_count: Map<ContractAddress, u256>,
    skill_verified: Map<(ContractAddress, felt252), bool>,
    work_entries: Map<(ContractAddress, u256), WorkEntries>,
    work_entry_count: Map<ContractAddress, u256>,
    profile_is_public: Map<ContractAddress, bool>,
    reputation_score: Map<ContractAddress, u256>,
}


// --------------- Events ------------------
#[derive(Drop, starknet::Event)]
pub struct ProfileCreated {
    #[key]
    pub profile_address: ContractAddress,
    pub name: felt252,
    pub bio: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct ProfileUpdated {
    #[key]
    pub profile_address: ContractAddress,
    pub name: felt252,
    pub bio: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct PortfolioLinkAdded {
    #[key]
    pub profile_address: ContractAddress,
    pub index: u256,
    pub link: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct SkillAdded {
    #[key]
    pub profile_address: ContractAddress,
    pub index: u256,
    pub skill: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct SkillVerified {
    #[key]
    pub profile_address: ContractAddress,
    pub skill: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct WorkEntryAdded {
    #[key]
    pub profile_address: ContractAddress,
    pub index: u256,
    pub org: felt252,
    pub role: felt252,
    pub duration_months: u64,
    pub description: felt252,
}

#[derive(Drop, starknet::Event)]
pub struct ProfilePrivacyToggled {
    #[key]
    pub profile_address: ContractAddress,
    pub is_public: bool,
}

#[derive(Drop, starknet::Event)]
pub struct ReputationUpdated {
    #[key]
    pub profile_address: ContractAddress,
    pub new_score: u256,
}


// --------------- Impl --------------------
#[abi(embed_v0)]
impl ProfileRegistryImpl of IDispute<ContractState> {
    // Multi-sig init (called once)
    fn init(ref self: ContractState, multi_sig: ContractAddress) {
        let zero: ContractAddress = contract_address_const::<'0x0'>();
        let current: ContractAddress = self.multi_sig.read();
        assert(current == zero, 'only_multisig');
        self.multi_sig.write(multi_sig);
    }
}
