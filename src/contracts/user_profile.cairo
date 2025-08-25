use starknet::ContractAddress;

#[starknet::interface]
trait IUserProfile<TContractState> {
    fn register_profile(
        ref self: TContractState,
        name: felt252,
        bio: felt252,
        location: felt252,
        privacy_level: u8
    );
    
    fn update_profile(
        ref self: TContractState,
        name: felt252,
        bio: felt252,
        location: felt252,
        privacy_level: u8
    );
    
    fn get_profile(self: @TContractState, user: ContractAddress) -> UserProfile;
    fn is_profile_public(self: @TContractState, user: ContractAddress) -> bool;
    fn get_profile_count(self: @TContractState) -> u256;
}

#[derive(Drop, Serde, starknet::Store)]
struct UserProfile {
    owner: ContractAddress,
    name: felt252,
    bio: felt252,
    location: felt252,
    created_at: u64,
    updated_at: u64,
    privacy_level: u8, // 0: public, 1: limited, 2: private
    verification_status: u8, // 0: unverified, 1: pending, 2: verified
    reputation_score: u256,
}

#[starknet::contract]
mod UserProfile {
    use super::{IUserProfile, UserProfile as ProfileStruct};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map
    };

    #[storage]
    struct Storage {
        profiles: Map<ContractAddress, ProfileStruct>,
        profile_exists: Map<ContractAddress, bool>,
        profile_count: u256,
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ProfileRegistered: ProfileRegistered,
        ProfileUpdated: ProfileUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct ProfileRegistered {
        user: ContractAddress,
        name: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct ProfileUpdated {
        user: ContractAddress,
        timestamp: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.profile_count.write(0);
    }

    #[abi(embed_v0)]
    impl UserProfileImpl of IUserProfile<ContractState> {
        fn register_profile(
            ref self: ContractState,
            name: felt252,
            bio: felt252,
            location: felt252,
            privacy_level: u8
        ) {
            let caller = get_caller_address();
            assert(!self.profile_exists.read(caller), 'Profile already exists');
            assert(privacy_level <= 2, 'Invalid privacy level');

            let timestamp = get_block_timestamp();
            let profile = ProfileStruct {
                owner: caller,
                name,
                bio,
                location,
                created_at: timestamp,
                updated_at: timestamp,
                privacy_level,
                verification_status: 0,
                reputation_score: 0,
            };

            self.profiles.write(caller, profile);
            self.profile_exists.write(caller, true);
            self.profile_count.write(self.profile_count.read() + 1);

            self.emit(ProfileRegistered { user: caller, name, timestamp });
        }

        fn update_profile(
            ref self: ContractState,
            name: felt252,
            bio: felt252,
            location: felt252,
            privacy_level: u8
        ) {
            let caller = get_caller_address();
            assert(self.profile_exists.read(caller), 'Profile does not exist');
            assert(privacy_level <= 2, 'Invalid privacy level');

            let mut profile = self.profiles.read(caller);
            profile.name = name;
            profile.bio = bio;
            profile.location = location;
            profile.privacy_level = privacy_level;
            profile.updated_at = get_block_timestamp();

            self.profiles.write(caller, profile);
            self.emit(ProfileUpdated { user: caller, timestamp: profile.updated_at });
        }

        fn get_profile(self: @ContractState, user: ContractAddress) -> ProfileStruct {
            assert(self.profile_exists.read(user), 'Profile does not exist');
            let profile = self.profiles.read(user);
            
            // Privacy check
            let caller = get_caller_address();
            if profile.privacy_level == 2 && caller != user {
                panic!("Profile is private");
            }
            
            profile
        }

        fn is_profile_public(self: @ContractState, user: ContractAddress) -> bool {
            if !self.profile_exists.read(user) {
                return false;
            }
            let profile = self.profiles.read(user);
            profile.privacy_level == 0
        }

        fn get_profile_count(self: @ContractState) -> u256 {
            self.profile_count.read()
        }
    }
}
