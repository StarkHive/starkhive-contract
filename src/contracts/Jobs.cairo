#[starknet::contract]
pub mod Jobs {
    // use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starkhive_contract::base::types::{Applicant, ApplicationStatus, Job, Status};
    use starkhive_contract::contracts::MockUSDC::{IExternalDispatcher, IExternalDispatcherTrait};
    use starkhive_contract::interfaces::IJobs::IJobs;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{
        ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
        get_contract_address,
    };

    #[storage]
    struct Storage {
        applied_for_job: Map<(u256, ContractAddress), bool>,
        jobs: Map<u256, Job>,
        job_counter: u256,
        job_applicants: Map<(u256, u256), Applicant>,
        strk_token_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        JobCreated: JobCreated,
        ApplicationSubmitted: ApplicationSubmitted,
        JobAssigned: JobAssigned,
        JobSubmitted: JobSubmitted,
        JobAccepted: JobAccepted,
        JobRejected: JobRejected,
        JobDisputed: JobDisputed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct JobCreated {
        #[key]
        pub id: u256,
        pub title: felt252,
        pub author: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct JobAssigned {
        #[key]
        pub job_id: u256,
        pub assignee: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct JobRejected {
        #[key]
        pub job_id: u256,
        pub assignee: ContractAddress,
    }
    #[derive(Drop, starknet::Event)]
    pub struct JobDisputed {
        #[key]
        pub job_id: u256,
        pub assignee: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct JobAccepted {
        #[key]
        pub job_id: u256,
        pub assignee: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct JobSubmitted {
        #[key]
        pub job_id: u256,
        pub assignee: ContractAddress,
    }


    #[derive(Drop, starknet::Event)]
    pub struct ApplicationSubmitted {
        #[key]
        pub job_id: u256,
        pub applicant: ContractAddress,
        pub time: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, erc20: ContractAddress) {
        self.strk_token_address.write(erc20);
    }

    #[abi(embed_v0)]
    impl JobsImpl of IJobs<ContractState> {
        fn register(ref self: ContractState) {}
        fn create_job(
            ref self: ContractState,
            title: felt252,
            description: ByteArray,
            budget: u256,
            deadline: u64,
            requirements: ByteArray,
            owner: ContractAddress,
        ) -> u256 {
            // Get the current job_id
            let id = self.job_counter.read() + 1;

            let timestamp = get_block_timestamp();

            let applicant: ContractAddress = contract_address_const::<'0x0'>();

            let new_job = Job {
                job_id: id,
                title,
                description,
                budget,
                deadline,
                requirements,
                owner,
                status: Status::Open,
                applications: 0,
                applicant,
                updated_at: timestamp,
                created_at: timestamp,
            };

            let token = self.strk_token_address.read();

            let erc20_dispatcher = IExternalDispatcher { contract_address: token };
            let contract_address = get_contract_address();
            let success = erc20_dispatcher.transferr(contract_address, budget);
            // self.deposit(owner, token, budget);

            assert(success, 'budget deposit failed');

            self.jobs.write(id, new_job);

            self.job_counter.write(id);

            self.emit(JobCreated { id, title, author: owner });

            id
        }

        fn apply_for_job(ref self: ContractState, job_id: u256, qualification: ByteArray) -> u256 {
            let caller = get_caller_address();
            let timestamp = get_block_timestamp();
            let mut applied = self.applied_for_job.read((job_id, caller));

            assert(!applied, 'Already Applied');

            let mut job = self.jobs.read(job_id);

            job.applications += 1;

            let applicant_id = job.applications;

            assert(job.status == Status::Open, 'Applications not Open');
            assert(job.owner != caller, 'Cannot apply for your job');

            let mut applicant = Applicant {
                address: caller,
                job_id,
                applicant_id: applicant_id,
                qualification,
                application_status: ApplicationStatus::Pending,
                applied_at: timestamp,
                updated_at: timestamp,
            };

            self.job_applicants.write((job_id, job.applications), applicant);

            self.applied_for_job.write((job_id, caller), true);

            self.jobs.write(job_id, job);

            self.emit(ApplicationSubmitted { job_id, applicant: caller, time: timestamp });

            applicant_id
        }

        fn submit_job(ref self: ContractState, job_id: u256, applicant_id: u256) {
            let caller = get_caller_address();
            let mut job = self.get_job(job_id);
            let mut applicant = self.job_applicants.read((job_id, applicant_id));

            assert(applicant.job_id == job_id, 'Not your job');

            applicant.application_status = ApplicationStatus::Reviewing;

            job.status = Status::Reviewing;

            self.job_applicants.write((job_id, applicant_id), applicant);

            self.jobs.write(job_id, job);

            self.emit(JobSubmitted { job_id, assignee: caller });
        }

        fn approve_submission(ref self: ContractState, job_id: u256, applicant_id: u256) {
            let caller = get_caller_address();
            let mut job = self.get_job(job_id);
            let mut applicant = self.job_applicants.read((job_id, applicant_id));

            assert(job.owner == caller, 'Not your job');

            applicant.application_status = ApplicationStatus::Accepted;

            job.status = Status::Completed;

            // let token = self.strk_token_address.read();

            let success = self.pay_applicant(job.applicant, job.budget);

            assert(success, 'Applicant payment failed');

            self.job_applicants.write((job_id, applicant_id), applicant);

            self.jobs.write(job_id, job);

            self.emit(JobAccepted { job_id, assignee: caller });
        }
        fn cancel_job(ref self: ContractState, job_id: u256, applicant_id: u256) {
            let caller = get_caller_address();
            let mut job = self.get_job(job_id);
            let mut applicant = self.job_applicants.read((job_id, applicant_id));

            assert(job.owner == caller, 'Not your job');

            applicant.application_status = ApplicationStatus::JobCancelled;

            job.status = Status::Cancelled;

            self.job_applicants.write((job_id, applicant_id), applicant);

            self.jobs.write(job_id, job);

            self.emit(JobAccepted { job_id, assignee: caller });
        }

        fn reject_submission(ref self: ContractState, job_id: u256, applicant_id: u256) {
            let caller = get_caller_address();
            let mut job = self.get_job(job_id);
            let mut applicant = self.job_applicants.read((job_id, applicant_id));

            assert(job.owner == caller, 'Not your job');

            applicant.application_status = ApplicationStatus::Rejected;

            job.status = Status::Rejected;

            self.job_applicants.write((job_id, applicant_id), applicant);

            self.jobs.write(job_id, job);

            self.emit(JobRejected { job_id, assignee: caller });
        }

        fn request_changes(ref self: ContractState, job_id: u256, applicant_id: u256) {
            let caller = get_caller_address();
            let mut job = self.get_job(job_id);
            let mut applicant = self.job_applicants.read((job_id, applicant_id));

            assert(job.owner == caller, 'Not your job');

            applicant.application_status = ApplicationStatus::Pending;

            job.status = Status::Disputed;

            self.job_applicants.write((job_id, applicant_id), applicant);

            self.jobs.write(job_id, job);

            self.emit(JobDisputed { job_id, assignee: caller });
        }

        fn get_applicant(self: @ContractState, job_id: u256, applicant_id: u256) -> Applicant {
            let applicant = self.job_applicants.read((job_id, applicant_id));
            applicant
        }

        fn assign_job(ref self: ContractState, job_id: u256, applicant_id: u256) {
            let mut job = self.get_job(job_id);
            let all_applicants = self.get_all_job_applicants(job_id);
            let total: u256 = all_applicants.len().into();

            let mut assignee: ContractAddress = contract_address_const::<'0x0'>();
            let mut found = false;

            for i in 0..total {
                let mut applicant = self.get_applicant(job_id, i + 1);

                if applicant.applicant_id == applicant_id {
                    assignee = applicant.address;
                    job.applicant = assignee;
                    applicant.application_status = ApplicationStatus::Assigned;
                    found = true;
                } else {
                    applicant.application_status = ApplicationStatus::Rejected;
                }

                self.job_applicants.write((job_id, i + 1), applicant);
            }

            job.status = Status::InProgress;
            self.jobs.write(job_id, job);
            self.emit(JobAssigned { job_id, assignee });
        }


        fn get_all_job_applicants(
            self: @ContractState, job_id: u256,
        ) -> Array<Applicant> { // let job = self.get_job(job_id);
            let job = self.jobs.read(job_id);
            let mut max_application_id = job.applications;
            let mut applicants = ArrayTrait::new();

            for i in 0..max_application_id {
                let applicant = self.get_applicant(job_id, i);
                applicants.append(applicant);
                max_application_id -= 1;
            } //scarb fmt can be acting crazy by removing this semicolon and causing workflow to fail

            applicants
        }

        fn get_job(self: @ContractState, job_id: u256) -> Job {
            // Retrieve and return the job
            let job = self.jobs.read(job_id);
            job
        }


        fn deposit(ref self: ContractState, depositor: ContractAddress, amount: u256) -> bool {
            let token = self.strk_token_address.read();
            let erc20_dispatcher = IExternalDispatcher { contract_address: token };
            let contract_address = get_contract_address();
            let caller_balance = erc20_dispatcher.balance(depositor);
            erc20_dispatcher.approve_user(contract_address, amount);
            let contract_allowance = erc20_dispatcher.get_allowance(depositor, contract_address);
            assert(contract_allowance >= amount, 'INSUFFICIENT_ALLOWANCE');
            assert(caller_balance >= amount, 'insufficient bal');

            let pull_back_res = erc20_dispatcher
                .transfer_fromm(depositor, contract_address, amount);
            assert(pull_back_res, 'DEPOSIT failed');

            pull_back_res
        }

        fn pay_applicant(ref self: ContractState, receiver: ContractAddress, amount: u256) -> bool {
            let token = self.strk_token_address.read();
            let erc20_dispatcher = IExternalDispatcher { contract_address: token };
            let contract_address = get_contract_address();
            let contract_balance = erc20_dispatcher.balance(contract_address);
            assert(contract_balance >= amount, 'insufficient bal');
            let success = erc20_dispatcher.transferr(receiver, amount);
            assert(success, 'payment failed');
            success
        }

        fn check_balance(self: @ContractState, address: ContractAddress) -> u256 {
            let token = self.strk_token_address.read();
            let erc20_dispatcher = IExternalDispatcher { contract_address: token };

            let balance = erc20_dispatcher.balance(address);

            balance
        }
    }
}

