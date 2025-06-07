use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, CheatTarget};
use core::array::ArrayTrait;
use core::array::SpanTrait;
use core::option::OptionTrait;
use core::traits::Into;
use core::traits::TryInto;
use core::result::ResultTrait;
use starknet::ContractAddress;
use starkhive_contract::interfaces::IReputationNFT::{IReputationNFT, IReputationNFTDispatcher, IReputationNFTDispatcherTrait};

mod test_contract {
    use super::*;

    fn setup() -> (ContractAddress, ContractAddress, ContractAddress) {
        let admin = starknet::contract_address_const::<'admin'>();
        let jobs_contract = starknet::contract_address_const::<'jobs'>();
        
        let contract = declare('ReputationNFT');
        let contract_address = contract.deploy(@array![
            'StarkHive Reputation',
            'SHREP',
            jobs_contract.into(),
            admin.into()
        ]).unwrap();

        (contract_address, admin, jobs_contract)
    }

    #[test]
    fn test_mint_reputation_nft() {
        let (contract_address, admin, jobs_contract) = setup();
        let dispatcher = IReputationNFTDispatcher { contract_address };
        
        // Set caller as jobs contract
        start_prank(CheatTarget::One(contract_address), jobs_contract);

        // Test minting
        let recipient = starknet::contract_address_const::<'recipient'>();
        let token_id = dispatcher.mint(recipient, 'TECHNOLOGY');
        
        // Verify token ownership
        let owner = dispatcher.owner_of(token_id);
        assert(owner == recipient, 'Wrong token owner');
        
        // Verify skill category
        let category = dispatcher.get_skill_category(token_id);
        assert(category == 'TECHNOLOGY', 'Wrong skill category');

        stop_prank(CheatTarget::One(contract_address));
    }

    #[test]
    fn test_update_rating() {
        let (contract_address, admin, jobs_contract) = setup();
        let dispatcher = IReputationNFTDispatcher { contract_address };
        
        // Set caller as jobs contract
        start_prank(CheatTarget::One(contract_address), jobs_contract);

        // Test minting and rating update
        let recipient = starknet::contract_address_const::<'recipient'>();
        let token_id = dispatcher.mint(recipient, 'TECHNOLOGY');
        
        dispatcher.update_rating(token_id, 90_u8);
        let rating = dispatcher.get_rating(token_id);
        assert(rating == 90_u8, 'Wrong rating');

        stop_prank(CheatTarget::One(contract_address));
    }

    #[test]
    fn test_add_achievement() {
        let (contract_address, admin, jobs_contract) = setup();
        let dispatcher = IReputationNFTDispatcher { contract_address };
        
        // Set caller as jobs contract
        start_prank(CheatTarget::One(contract_address), jobs_contract);

        // Test minting and achievement
        let recipient = starknet::contract_address_const::<'recipient'>();
        let token_id = dispatcher.mint(recipient, 'TECHNOLOGY');
        
        dispatcher.add_achievement(token_id, 'COMPLETED_EXPERT_JOB');
        let achievements = dispatcher.get_achievements(token_id);
        assert(achievements.len() == 1_u32, 'Wrong achievement count');
        assert(*achievements.at(0) == 'COMPLETED_EXPERT_JOB', 'Wrong achievement');

        stop_prank(CheatTarget::One(contract_address));
    }

    #[test]
    fn test_reputation_score() {
        let (contract_address, admin, jobs_contract) = setup();
        let dispatcher = IReputationNFTDispatcher { contract_address };
        
        // Set caller as jobs contract
        start_prank(CheatTarget::One(contract_address), jobs_contract);

        // Test minting and score calculation
        let recipient = starknet::contract_address_const::<'recipient'>();
        let token_id = dispatcher.mint(recipient, 'TECHNOLOGY');
        
        dispatcher.update_rating(token_id, 90_u8);
        dispatcher.add_achievement(token_id, 'COMPLETED_EXPERT_JOB');
        dispatcher.add_achievement(token_id, 'HIGH_RATING');
        
        let score = dispatcher.get_reputation_score(token_id);
        assert(score == 9100_u256, 'Wrong reputation score');

        stop_prank(CheatTarget::One(contract_address));
    }

    #[test]
    #[should_panic(expected: 'Soulbound token - non-transferable')]
    fn test_transfer_prevention() {
        let (contract_address, admin, jobs_contract) = setup();
        let dispatcher = IReputationNFTDispatcher { contract_address };
        
        // Set caller as jobs contract
        start_prank(CheatTarget::One(contract_address), jobs_contract);

        // Mint token
        let owner = starknet::contract_address_const::<'owner'>();
        let token_id = dispatcher.mint(owner, 'TECHNOLOGY');
        
        // Try to transfer (should fail)
        let recipient = starknet::contract_address_const::<'recipient'>();
        dispatcher.transfer_from(owner, recipient, token_id);

        stop_prank(CheatTarget::One(contract_address));
    }
} 