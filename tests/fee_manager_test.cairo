use snforge_std::prelude::*;
use starkhive_contract::contracts::fee_manager;

describe! {
    fn test_fee_collection_and_withdrawal() {
        // Setup initial context
        let mut contract = fee_manager::FeeManager::deploy();

        // Admin sets fee rate for job type 1 (100 = 1%)
        contract.set_fee_rate(1, 100);

        // Simulate job fee collection: user completes a job, pays 1000 tokens
        let result = contract.collect_fee(1, 1000);

        // Assert event emitted
        assert_event_emitted!(
            result.events,
            fee_manager::FeeCollected {
                job_type: 1,
                amount: 1000,
                fee: 10  // 1% of 1000
            }
        );

        // Check treasury balance
        let treasury_balance = contract.get_treasury_balance();
        assert_eq!(treasury_balance, 10);

        // Register a stakeholder and distribute
        contract.register_stakeholder(account(1), 100); // 100% weight to account 1
        let dist_result = contract.distribute_fees();

        assert_event_emitted!(
            dist_result.events,
            fee_manager::FeeDistributed {
                stakeholder: account(1),
                amount: 10
            }
        );

        // Withdraw from treasury
        let withdraw_result = contract.withdraw(account(1), 10);
        assert_event_emitted!(
            withdraw_result.events,
            fee_manager::FeeWithdrawn {
                to: account(1),
                amount: 10
            }
        );
    }
}
