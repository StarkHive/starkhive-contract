use starknet::ContractAddress;

#[starknet::interface]
trait IPortfolioLinks<TContractState> {
    fn add_portfolio_link(ref self: TContractState, title: felt252, url: felt252, link_type: u8);
    fn update_portfolio_link(ref self: TContractState, link_id: u32, title: felt252, url: felt252, link_type: u8);
    fn remove_portfolio_link(ref self: TContractState, link_id: u32);
    fn get_portfolio_links(self: @TContractState, user: ContractAddress) -> Array<PortfolioLink>;
}

#[derive(Drop, Serde, starknet::Store)]
struct PortfolioLink {
    id: u32,
    user: ContractAddress,
    title: felt252,
    url: felt252,
    link_type: u8, // 0: website, 1: github, 2: linkedin, 3: other
    created_at: u64,
    updated_at: u64,
}

#[starknet::contract]
mod PortfolioLinks {
    use super::{IPortfolioLinks, PortfolioLink};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map
    };

    #[storage]
    struct Storage {
        portfolio_links: Map<(ContractAddress, u32), PortfolioLink>,
        user_link_count: Map<ContractAddress, u32>,
        next_link_id: Map<ContractAddress, u32>,
        max_links_per_user: u32,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PortfolioLinkAdded: PortfolioLinkAdded,
        PortfolioLinkUpdated: PortfolioLinkUpdated,
        PortfolioLinkRemoved: PortfolioLinkRemoved,
    }

    #[derive(Drop, starknet::Event)]
    struct PortfolioLinkAdded {
        user: ContractAddress,
        link_id: u32,
        title: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct PortfolioLinkUpdated {
        user: ContractAddress,
        link_id: u32,
    }

    #[derive(Drop, starknet::Event)]
    struct PortfolioLinkRemoved {
        user: ContractAddress,
        link_id: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.max_links_per_user.write(10); // Limit to prevent spam
    }

    #[abi(embed_v0)]
    impl PortfolioLinksImpl of IPortfolioLinks<ContractState> {
        fn add_portfolio_link(ref self: ContractState, title: felt252, url: felt252, link_type: u8) {
            let caller = get_caller_address();
            assert(link_type <= 3, 'Invalid link type');
            assert(self.user_link_count.read(caller) < self.max_links_per_user.read(), 'Max links reached');

            let link_id = self.next_link_id.read(caller);
            let timestamp = get_block_timestamp();
            
            let portfolio_link = PortfolioLink {
                id: link_id,
                user: caller,
                title,
                url,
                link_type,
                created_at: timestamp,
                updated_at: timestamp,
            };

            self.portfolio_links.write((caller, link_id), portfolio_link);
            self.user_link_count.write(caller, self.user_link_count.read(caller) + 1);
            self.next_link_id.write(caller, link_id + 1);

            self.emit(PortfolioLinkAdded { user: caller, link_id, title });
        }

        fn update_portfolio_link(ref self: ContractState, link_id: u32, title: felt252, url: felt252, link_type: u8) {
            let caller = get_caller_address();
            assert(link_type <= 3, 'Invalid link type');
            
            let link_key = (caller, link_id);
            let mut portfolio_link = self.portfolio_links.read(link_key);
            assert(portfolio_link.user == caller, 'Link not found');

            portfolio_link.title = title;
            portfolio_link.url = url;
            portfolio_link.link_type = link_type;
            portfolio_link.updated_at = get_block_timestamp();

            self.portfolio_links.write(link_key, portfolio_link);
            self.emit(PortfolioLinkUpdated { user: caller, link_id });
        }

        fn remove_portfolio_link(ref self: ContractState, link_id: u32) {
            let caller = get_caller_address();
            let link_key = (caller, link_id);
            let portfolio_link = self.portfolio_links.read(link_key);
            assert(portfolio_link.user == caller, 'Link not found');

            // Clear the link
            let empty_link = PortfolioLink {
                id: 0,
                user: caller,
                title: 0,
                url: 0,
                link_type: 0,
                created_at: 0,
                updated_at: 0,
            };

            self.portfolio_links.write(link_key, empty_link);
            self.user_link_count.write(caller, self.user_link_count.read(caller) - 1);

            self.emit(PortfolioLinkRemoved { user: caller, link_id });
        }

        fn get_portfolio_links(self: @ContractState, user: ContractAddress) -> Array<PortfolioLink> {
            let mut links = ArrayTrait::new();
            let next_id = self.next_link_id.read(user);
            
            let mut i = 0_u32;
            while i < next_id {
                let link_key = (user, i);
                let portfolio_link = self.portfolio_links.read(link_key);
                
                if portfolio_link.user == user && portfolio_link.id != 0 {
                    links.append(portfolio_link);
                }
                i += 1;
            };
            
            links
        }
    }
}
