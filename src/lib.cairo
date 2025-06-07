pub mod contracts {
    pub mod Dispute;
    pub mod Jobs;
    pub mod fee_manager; // 🔐 FeeManager contract for fee collection and treasury
    pub mod MockUSDC;
    pub mod ReputationNFT;
}

pub mod base {
    pub mod types;
    pub mod reputation_metadata;
}

pub mod interfaces {
    pub mod IDispute;
    pub mod IJobs;
    pub mod IReputationNFT;
}
