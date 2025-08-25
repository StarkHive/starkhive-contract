use starknet::ContractAddress;

#[starknet::interface]
trait IWorkHistory<TContractState> {
    fn add_work_experience(
        ref self: TContractState,
        company: felt252,
        position: felt252,
        start_date: u64,
        end_date: u64,
        description: felt252
    );
    fn update_work_experience(
        ref self: TContractState,
        experience_id: u32,
        company: felt252,
        position: felt252,
        start_date: u64,
        end_date: u64,
        description: felt252
    );
    fn get_work_history(self: @TContractState, user: ContractAddress) -> Array<WorkExperience>;
    fn verify_work_experience(ref self: TContractState, user: ContractAddress, experience_id: u32);
}

#[derive(Drop, Serde, starknet::Store)]
struct WorkExperience {
    id: u32,
    user: ContractAddress,
    company: felt252,
    position: felt252,
    start_date: u64,
    end_date: u64, // 0 for current position
    description: felt252,
    verified: bool,
    created_at: u64,
}

#[starknet::contract]
mod WorkHistory {
    use super::{IWorkHistory, WorkExperience};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map
    };

    #[storage]
    struct Storage {
        work_experiences: Map<(ContractAddress, u32), WorkExperience>,
        user_experience_count: Map<ContractAddress, u32>,
        next_experience_id: Map<ContractAddress, u32>,
        verifiers: Map<ContractAddress, bool>,
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        WorkExperienceAdded: WorkExperienceAdded,
        WorkExperienceVerified: WorkExperienceVerified,
    }

    #[derive(Drop, starknet::Event)]
    struct WorkExperienceAdded {
        user: ContractAddress,
        experience_id: u32,
        company: felt252,
        position: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct WorkExperienceVerified {
        user: ContractAddress,
        experience_id: u32,
        verifier: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.verifiers.write(owner, true);
    }

    #[abi(embed_v0)]
    impl WorkHistoryImpl of IWorkHistory<ContractState> {
        fn add_work_experience(
            ref self: ContractState,
            company: felt252,
            position: felt252,
            start_date: u64,
            end_date: u64,
            description: felt252
        ) {
            let caller = get_caller_address();
            assert(start_date > 0, 'Invalid start date');
            assert(end_date == 0 || end_date > start_date, 'Invalid end date');

            let experience_id = self.next_experience_id.read(caller);
            let experience = WorkExperience {
                id: experience_id,
                user: caller,
                company,
                position,
                start_date,
                end_date,
                description,
                verified: false,
                created_at: get_block_timestamp(),
            };

            self.work_experiences.write((caller, experience_id), experience);
            self.user_experience_count.write(caller, self.user_experience_count.read(caller) + 1);
            self.next_experience_id.write(caller, experience_id + 1);

            self.emit(WorkExperienceAdded { user: caller, experience_id, company, position });
        }

        fn update_work_experience(
            ref self: ContractState,
            experience_id: u32,
            company: felt252,
            position: felt252,
            start_date: u64,
            end_date: u64,
            description: felt252
        ) {
            let caller = get_caller_address();
            let experience_key = (caller, experience_id);
            let mut experience = self.work_experiences.read(experience_key);
            
            assert(experience.user == caller, 'Experience not found');
            assert(start_date > 0, 'Invalid start date');
            assert(end_date == 0 || end_date > start_date, 'Invalid end date');

            experience.company = company;
            experience.position = position;
            experience.start_date = start_date;
            experience.end_date = end_date;
            experience.description = description;
            experience.verified = false; // Reset verification on update

            self.work_experiences.write(experience_key, experience);
        }

        fn get_work_history(self: @ContractState, user: ContractAddress) -> Array<WorkExperience> {
            let mut experiences = ArrayTrait::new();
            let experience_count = self.user_experience_count.read(user);
            let next_id = self.next_experience_id.read(user);
            
            let mut i = 0_u32;
            while i < next_id {
                let experience_key = (user, i);
                let experience = self.work_experiences.read(experience_key);
                
                if experience.user == user {
                    experiences.append(experience);
                }
                i += 1;
            };
            
            experiences
        }

        fn verify_work_experience(ref self: ContractState, user: ContractAddress, experience_id: u32) {
            let caller = get_caller_address();
            assert(self.verifiers.read(caller), 'Not authorized to verify');

            let experience_key = (user, experience_id);
            let mut experience = self.work_experiences.read(experience_key);
            assert(experience.user == user, 'Experience not found');

            experience.verified = true;
            self.work_experiences.write(experience_key, experience);
            
            self.emit(WorkExperienceVerified { user, experience_id, verifier: caller });
        }
    }
}
