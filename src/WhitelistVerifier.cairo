use starknet::{ContractAddress};

#[starknet::interface]
pub trait IWhitelistVerifier<TContractState> {
    fn is_whitelisted(self: @TContractState, wallet_address: ContractAddress) -> bool;
    fn add_to_whitelist(ref self: TContractState, wallet_address: ContractAddress);
    fn remove_from_whitelist(ref self: TContractState, wallet_address: ContractAddress);
    fn grant_admin_role(ref self: TContractState, new_admin: ContractAddress);
}

#[starknet::contract]
pub mod WhitelistVerifier {
    use starknet::{ContractAddress, get_caller_address};
    use starknet::event::EventEmitter;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // Role definition
    const ADMIN_ROLE: felt252 = selector!("ADMIN_ROLE");


    // AccessControl
    #[abi(embed_v0)]
    impl AccessControlImpl = AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;    

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // Map the contract address to a boolean value
        whitelist: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        AddToWhitelist: AddToWhitelist,
        RemoveFromWhitelist: RemoveFromWhitelist,
        GrantAdminRole: GrantAdminRole,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct AddToWhitelist  {
        wallet_address: ContractAddress,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct RemoveFromWhitelist  {
        wallet_address: ContractAddress,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct GrantAdminRole {
        admin_address: ContractAddress,
        new_admin: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState){
        self.accesscontrol.initializer();
        // Grant the contract deployer the admin role:
        self.accesscontrol._grant_role(ADMIN_ROLE, get_caller_address());
    }

    #[abi(embed_v0)]
    impl WhitelistVerifierImpl of super::IWhitelistVerifier<ContractState> {
        fn is_whitelisted(self: @ContractState, wallet_address: ContractAddress) -> bool {
            self.whitelist.read(wallet_address)
        }

        fn add_to_whitelist(ref self: ContractState, wallet_address: ContractAddress) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.whitelist.write(wallet_address, true);
            self.emit(AddToWhitelist { wallet_address: wallet_address });
        }

        fn remove_from_whitelist(ref self: ContractState, wallet_address: ContractAddress) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.whitelist.write(wallet_address, false);
            self.emit(RemoveFromWhitelist { wallet_address: wallet_address });
        }

        fn grant_admin_role(ref self: ContractState, new_admin: ContractAddress) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.accesscontrol._grant_role(ADMIN_ROLE, new_admin);
            self.emit(GrantAdminRole { admin_address: get_caller_address(), new_admin: new_admin });
        }
    }

}