#[starknet::contract]
mod ReputationNFT {
    use core::panic_with_felt252;
    use core::num::traits::Zero;
    use starknet::storage::StorageMapReadAccess;
    use starknet::storage::StorageMapWriteAccess;
    use starknet::storage::StoragePointerReadAccess;
    use starknet::storage::Map;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin::token::erc721::ERC721;
    use array::ArrayTrait;
    use zeroable::Zeroable;
    use traits::Into;
    use starkhive_contract::interfaces::IReputationNFT::IReputationNFT;

    #[storage]
    struct Storage {
        // ERC721 storage
        _name: felt252,
        _symbol: felt252,
        _owners: Map<u256, ContractAddress>,
        _balances: Map<ContractAddress, u256>,
        _token_approvals: Map<u256, ContractAddress>,
        _operator_approvals: Map<(ContractAddress, ContractAddress), bool>,
        _token_uri: Map<u256, Array<felt252>>,
        
        // Reputation specific storage
        _next_token_id: u256,
        _skill_categories: Map<u256, felt252>,
        _ratings: Map<u256, u8>,
        _achievements: Map<u256, Array<felt252>>,
        _jobs_contract: ContractAddress,
        _admin: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        ApprovalForAll: ApprovalForAll,
        RatingUpdated: RatingUpdated,
        AchievementAdded: AchievementAdded,
        MetadataUpdated: MetadataUpdated
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        approved: ContractAddress,
        token_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ApprovalForAll {
        owner: ContractAddress,
        operator: ContractAddress,
        approved: bool
    }

    #[derive(Drop, starknet::Event)]
    struct RatingUpdated {
        token_id: u256,
        new_rating: u8
    }

    #[derive(Drop, starknet::Event)]
    struct AchievementAdded {
        token_id: u256,
        achievement: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct MetadataUpdated {
        token_id: u256,
        uri: Array<felt252>
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        jobs_contract: ContractAddress,
        admin: ContractAddress
    ) {
        self._name.write(name);
        self._symbol.write(symbol);
        self._jobs_contract.write(jobs_contract);
        self._admin.write(admin);
        self._next_token_id.write(1);
    }


    #[abi(embed_v0)]
    impl ReputationNFT of IReputationNFT<ContractState> {
                fn name(self: @ContractState) -> felt252 {
            self._name.read()
        }

                fn symbol(self: @ContractState) -> felt252 {
            self._symbol.read()
        }

        fn token_uri(self: @ContractState, token_id: u256) -> Array<felt252> {
            assert(self._owners.read(token_id).is_non_zero(), 'Token does not exist');
            self._token_uri.read(token_id)
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self._owners.read(token_id);
            assert(owner.is_non_zero(), 'Token does not exist');
            owner
        }



        

        fn get_skill_category(self: @ContractState, token_id: u256) -> felt252 {
            assert(self._owners.read(token_id).is_non_zero(), 'Token does not exist');
            self._skill_categories.read(token_id)
        }

        fn get_rating(self: @ContractState, token_id: u256) -> u8 {
            assert(self._owners.read(token_id).is_non_zero(), 'Token does not exist');
            self._ratings.read(token_id)
        }

        fn get_achievements(self: @ContractState, token_id: u256) -> Array<felt252> {
            assert(self._owners.read(token_id).is_non_zero(), 'Token does not exist');
            self._achievements.read(token_id)
        }

        fn get_reputation_score(self: @ContractState, token_id: u256) -> u256 {
            assert(self._owners.read(token_id).is_non_zero(), 'Token does not exist');
            let rating = self._ratings.read(token_id).into();
            let achievements = self._achievements.read(token_id);
            // Basic score calculation: rating * 100 + (achievements.len() * 50)
            rating * 100 + (achievements.len().into() * 50)
        }

        fn mint(
            ref self: ContractState, 
            to: ContractAddress, 
            skill_category: felt252
        ) -> u256 {
            // Only jobs contract or admin can mint
            let caller = get_caller_address();
            assert(
                caller == self._jobs_contract.read() || caller == self._admin.read(),
                'Unauthorized'
            );
            
            let token_id = self._next_token_id.read();
            self._mint(to, token_id);
            self._skill_categories.write(token_id, skill_category);
            self._next_token_id.write(token_id + 1);
            token_id
        }

        fn batch_mint(
            ref self: ContractState,
            to: Array<ContractAddress>,
            skill_categories: Array<felt252>
        ) -> Array<u256> {
            // Only jobs contract or admin can mint
            let caller = get_caller_address();
            assert(
                caller == self._jobs_contract.read() || caller == self._admin.read(),
                'Unauthorized'
            );
            
            assert(to.len() == skill_categories.len(), 'Length mismatch');
            let mut token_ids = ArrayTrait::new();
            let mut i = 0;
            loop {
                if i >= to.len() {
                    break;
                }
                let token_id = self.mint(to[i], skill_categories[i]);
                token_ids.append(token_id);
                i += 1;
            };
            token_ids
        }

        fn update_rating(ref self: ContractState, token_id: u256, new_rating: u8) {
            // Only jobs contract or admin can update rating
            let caller = get_caller_address();
            assert(
                caller == self._jobs_contract.read() || caller == self._admin.read(),
                'Unauthorized'
            );
            assert(new_rating <= 100, 'Invalid rating');
            assert(self._owners.read(token_id).is_non_zero(), 'Token does not exist');
            
            self._ratings.write(token_id, new_rating);
            self.emit(Event::RatingUpdated(RatingUpdated { token_id, new_rating }));
        }

        fn add_achievement(ref self: ContractState, token_id: u256, achievement: felt252) {
            // Only jobs contract or admin can add achievements
            let caller = get_caller_address();
            assert(
                caller == self._jobs_contract.read() || caller == self._admin.read(),
                'Unauthorized'
            );
            assert(self._owners.read(token_id).is_non_zero(), 'Token does not exist');
            
            let mut achievements = self._achievements.read(token_id);
            achievements.append(achievement);
            self._achievements.write(token_id, achievements);
            self.emit(Event::AchievementAdded(AchievementAdded { token_id, achievement }));
        }

        fn set_metadata_uri(ref self: ContractState, token_id: u256, uri: Array<felt252>) {
            // Only admin can set metadata URI
            assert(get_caller_address() == self._admin.read(), 'Unauthorized');
            assert(self._owners.read(token_id).is_non_zero(), 'Token does not exist');
            
            self._token_uri.write(token_id, uri);
            self.emit(Event::MetadataUpdated(MetadataUpdated { token_id, uri }));
        }
    }

    #[external(v0)]
    fn transfer_from(
        ref self: ContractState,
        _from: ContractAddress,
        _to: ContractAddress,
        _token_id: u256
    ) {
        // Prevent transfers - soulbound implementation
        panic_with_felt252('Soulbound token - non-transferable');
    }

    #[external(v0)]
    fn safe_transfer_from(
        ref self: ContractState,
        _from: ContractAddress,
        _to: ContractAddress,
        _token_id: u256,
        _data: Array<felt252>
    ) {
        // Prevent transfers - soulbound implementation
        panic_with_felt252('Soulbound token - non-transferable');
    }

    #[internal]
    fn _mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
        assert(to.is_non_zero(), 'Invalid recipient');
        assert(self._owners.read(token_id).is_zero(), 'Token already exists');
        
        self._owners.write(token_id, to);
        self._balances.write(to, self._balances.read(to) + 1);
        
        self.emit(Event::Transfer(Transfer {
            from: Zeroable::zero(),
            to,
            token_id
        }));
    }
} 