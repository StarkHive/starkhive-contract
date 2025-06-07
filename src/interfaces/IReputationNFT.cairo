use starknet::ContractAddress;
#[starknet::interface]
pub trait IReputationNFT<TContractState> {
    // ERC721 core functions
    fn name(self: @TContractState,) -> felt252;
    fn symbol(self: @TContractState,) -> felt252;
    fn token_uri(self: @TContractState,token_id: u256) -> Array<felt252>;
    fn owner_of(self: @TContractState,token_id: u256) -> ContractAddress;
    
    // Reputation specific functions
    fn get_skill_category(self: @TContractState,token_id: u256) -> felt252;
    fn get_rating(self: @TContractState,token_id: u256) -> u8;
    fn get_achievements(self: @TContractState,token_id: u256) -> Array<felt252>;
    fn get_reputation_score(self: @TContractState,token_id: u256) -> u256;
    
    // Admin functions
    fn mint(ref self: TContractState,to: ContractAddress, skill_category: felt252) -> u256;
    fn batch_mint(ref self: TContractState,to: Array<ContractAddress>, skill_categories: Array<felt252>) -> Array<u256>;
    fn update_rating(ref self: TContractState,token_id: u256, new_rating: u8);
    fn add_achievement(ref self: TContractState,token_id: u256, achievement: felt252);
    fn set_metadata_uri(ref self: TContractState,token_id: u256, uri: Array<felt252>);
    
} 