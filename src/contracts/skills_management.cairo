use starknet::ContractAddress;

#[starknet::interface]
trait ISkillsManagement<TContractState> {
    fn add_skill(ref self: TContractState, skill_id: u32, proficiency_level: u8);
    fn remove_skill(ref self: TContractState, skill_id: u32);
    fn update_skill_proficiency(ref self: TContractState, skill_id: u32, proficiency_level: u8);
    fn get_user_skills(self: @TContractState, user: ContractAddress) -> Array<UserSkill>;
    fn verify_skill(ref self: TContractState, user: ContractAddress, skill_id: u32);
    fn get_skill_info(self: @TContractState, skill_id: u32) -> SkillInfo;
}

#[derive(Drop, Serde, starknet::Store)]
struct UserSkill {
    skill_id: u32,
    proficiency_level: u8, // 1-5 scale
    verified: bool,
    added_at: u64,
    verified_at: u64,
}

#[derive(Drop, Serde, starknet::Store)]
struct SkillInfo {
    id: u32,
    name: felt252,
    category: felt252,
    active: bool,
}

#[starknet::contract]
mod SkillsManagement {
    use super::{ISkillsManagement, UserSkill, SkillInfo};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map
    };

    #[storage]
    struct Storage {
        user_skills: Map<(ContractAddress, u32), UserSkill>,
        user_skill_count: Map<ContractAddress, u32>,
        skills_info: Map<u32, SkillInfo>,
        skill_exists: Map<u32, bool>,
        owner: ContractAddress,
        verifiers: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SkillAdded: SkillAdded,
        SkillVerified: SkillVerified,
        SkillRemoved: SkillRemoved,
    }

    #[derive(Drop, starknet::Event)]
    struct SkillAdded {
        user: ContractAddress,
        skill_id: u32,
        proficiency_level: u8,
    }

    #[derive(Drop, starknet::Event)]
    struct SkillVerified {
        user: ContractAddress,
        skill_id: u32,
        verifier: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct SkillRemoved {
        user: ContractAddress,
        skill_id: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.verifiers.write(owner, true);
        
        // Initialize some default skills
        self._add_skill_info(1, 'Cairo', 'Programming');
        self._add_skill_info(2, 'Rust', 'Programming');
        self._add_skill_info(3, 'JavaScript', 'Programming');
        self._add_skill_info(4, 'Smart Contracts', 'Blockchain');
        self._add_skill_info(5, 'Web3', 'Blockchain');
    }

    #[abi(embed_v0)]
    impl SkillsManagementImpl of ISkillsManagement<ContractState> {
        fn add_skill(ref self: ContractState, skill_id: u32, proficiency_level: u8) {
            let caller = get_caller_address();
            assert(self.skill_exists.read(skill_id), 'Skill does not exist');
            assert(proficiency_level >= 1 && proficiency_level <= 5, 'Invalid proficiency level');

            let skill_key = (caller, skill_id);
            let existing_skill = self.user_skills.read(skill_key);
            
            if existing_skill.skill_id == 0 {
                // New skill
                self.user_skill_count.write(caller, self.user_skill_count.read(caller) + 1);
            }

            let user_skill = UserSkill {
                skill_id,
                proficiency_level,
                verified: false,
                added_at: get_block_timestamp(),
                verified_at: 0,
            };

            self.user_skills.write(skill_key, user_skill);
            self.emit(SkillAdded { user: caller, skill_id, proficiency_level });
        }

        fn remove_skill(ref self: ContractState, skill_id: u32) {
            let caller = get_caller_address();
            let skill_key = (caller, skill_id);
            let existing_skill = self.user_skills.read(skill_key);
            
            assert(existing_skill.skill_id != 0, 'Skill not found');

            // Clear the skill
            let empty_skill = UserSkill {
                skill_id: 0,
                proficiency_level: 0,
                verified: false,
                added_at: 0,
                verified_at: 0,
            };
            
            self.user_skills.write(skill_key, empty_skill);
            self.user_skill_count.write(caller, self.user_skill_count.read(caller) - 1);
            
            self.emit(SkillRemoved { user: caller, skill_id });
        }

        fn update_skill_proficiency(ref self: ContractState, skill_id: u32, proficiency_level: u8) {
            let caller = get_caller_address();
            assert(proficiency_level >= 1 && proficiency_level <= 5, 'Invalid proficiency level');
            
            let skill_key = (caller, skill_id);
            let mut user_skill = self.user_skills.read(skill_key);
            assert(user_skill.skill_id != 0, 'Skill not found');

            user_skill.proficiency_level = proficiency_level;
            user_skill.verified = false; // Reset verification on update
            user_skill.verified_at = 0;
            
            self.user_skills.write(skill_key, user_skill);
        }

        fn get_user_skills(self: @ContractState, user: ContractAddress) -> Array<UserSkill> {
            let mut skills = ArrayTrait::new();
            let skill_count = self.user_skill_count.read(user);
            
            // This is a simplified implementation - in practice you'd want to store skill IDs separately
            let mut i = 1_u32;
            let mut found = 0_u32;
            
            while found < skill_count && i <= 100 { // Limit search to prevent infinite loops
                let skill_key = (user, i);
                let user_skill = self.user_skills.read(skill_key);
                
                if user_skill.skill_id != 0 {
                    skills.append(user_skill);
                    found += 1;
                }
                i += 1;
            };
            
            skills
        }

        fn verify_skill(ref self: ContractState, user: ContractAddress, skill_id: u32) {
            let caller = get_caller_address();
            assert(self.verifiers.read(caller), 'Not authorized to verify');

            let skill_key = (user, skill_id);
            let mut user_skill = self.user_skills.read(skill_key);
            assert(user_skill.skill_id != 0, 'Skill not found');

            user_skill.verified = true;
            user_skill.verified_at = get_block_timestamp();
            
            self.user_skills.write(skill_key, user_skill);
            self.emit(SkillVerified { user, skill_id, verifier: caller });
        }

        fn get_skill_info(self: @ContractState, skill_id: u32) -> SkillInfo {
            assert(self.skill_exists.read(skill_id), 'Skill does not exist');
            self.skills_info.read(skill_id)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _add_skill_info(ref self: ContractState, id: u32, name: felt252, category: felt252) {
            let skill_info = SkillInfo {
                id,
                name,
                category,
                active: true,
            };
            
            self.skills_info.write(id, skill_info);
            self.skill_exists.write(id, true);
        }
    }
}
