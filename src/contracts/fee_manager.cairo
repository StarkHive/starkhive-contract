use starknet::contract;
use starknet::storage;
use starknet::event;

#[event]
fn FeeCollected(job_type: u32, amount: u128, fee: u128);

#[event]
fn FeeDistributed(stakeholder: ContractAddress, amount: u128);

#[event]
fn FeeWithdrawn(to: ContractAddress, amount: u128);

#[contract]
mod FeeManager {
    #[storage]
    struct Storage {
        fee_rates: LegacyMap<u32, u128>, // job_type -> rate (basis points)
        treasury: u128,
        stakeholders: LegacyMap<ContractAddress, u128>, // address -> weight
    }

    #[external]
    fn set_fee_rate(ref self: ContractState, job_type: u32, rate: u128) {
        self.fee_rates.write(job_type, rate);
    }

    #[external]
    fn collect_fee(ref self: ContractState, job_type: u32, amount: u128) {
        let rate = self.fee_rates.read(job_type);
        let fee = amount * rate / 10000;
        self.treasury.write(self.treasury.read() + fee);

        emit FeeCollected(job_type, amount, fee);
    }

    #[external]
    fn get_treasury_balance(self: @ContractState) -> u128 {
        self.treasury.read()
    }

    #[external]
    fn register_stakeholder(ref self: ContractState, who: ContractAddress, weight: u128) {
        self.stakeholders.write(who, weight);
    }

    #[external]
    fn distribute_fees(ref self: ContractState) {
        let mut total_weight = 0;
        let mut shares: Array<(ContractAddress, u128)> = ArrayTrait::new();

        // Manually loop a small hardcoded stakeholder list for demo/test
        let addr = ContractAddress::try_from_felt(1);
        let weight = self.stakeholders.read(addr);
        total_weight += weight;
        shares.append((addr, weight));

        let treasury = self.treasury.read();

        for (who, weight) in shares.iter() {
            let share = treasury * weight / total_weight;
            emit FeeDistributed(who, share);
        }
    }

    #[external]
    fn withdraw(ref self: ContractState, to: ContractAddress, amount: u128) {
        let treasury = self.treasury.read();
        assert(treasury >= amount, 'Insufficient funds');
        self.treasury.write(treasury - amount);

        emit FeeWithdrawn(to, amount);
    }
}
