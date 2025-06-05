#[starknet::contract]
pub mod Jobs {
    use core::array::ArrayTrait;
    use core::option::OptionTrait;
    use starkhive_contract::base::types::{
        Applicant, ApplicationStatus, ExperienceLevel, Job, JobCategory, JobDuration, Status,
    };
    use starkhive_contract::interfaces::IJobs::IJobs;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{
        ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
    };

    #[storage]
    struct Storage {
        applied_for_job: Map<(u256, ContractAddress), bool>,
        jobs: Map<u256, Job>,
        job_counter: u256,
        job_applicants: Map<(u256, u256), Applicant>,
        // New indexing storage for efficient search
        jobs_by_category: Map<(u8, u256), u256>,
        category_job_count: Map<u8, u256>,
        jobs_by_location: Map<(felt252, u256), u256>,
        location_job_count: Map<felt252, u256>,
        jobs_by_duration: Map<(u8, u256), u256>,
        duration_job_count: Map<u8, u256>,
        jobs_by_experience: Map<(u8, u256), u256>,
        experience_job_count: Map<u8, u256>,
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
        pub category: JobCategory,
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

    #[abi(embed_v0)]
    impl JobsImpl of IJobs<ContractState> {
        fn register(ref self: ContractState) {}

        fn create_job(
            ref self: ContractState,
            title: felt252,
            description: ByteArray,
            budget: u256,
            budget_max: u256,
            deadline: u64,
            requirements: ByteArray,
            category: JobCategory,
            experience_level: ExperienceLevel,
            duration: JobDuration,
            location: felt252,
        ) -> u256 {
            assert(budget <= budget_max, 'Min budget exceeds max');
            assert(deadline > get_block_timestamp(), 'Deadline must be in future');

            // Get the current job_id
            let id = self.job_counter.read() + 1;
            let timestamp = get_block_timestamp();
            let owner = get_caller_address();
            let applicant: ContractAddress = contract_address_const::<'0x0'>();

            let new_job = Job {
                job_id: id,
                title,
                description,
                budget,
                budget_max,
                deadline,
                requirements,
                owner,
                status: Status::Open,
                applications: 0,
                applicant,
                updated_at: timestamp,
                created_at: timestamp,
                category,
                experience_level,
                duration,
                location,
            };

            self.jobs.write(id, new_job);

            // Index by category
            let mut cat = 0;
            if (category == JobCategory::Technology) {
                cat = 1;
            } else if (category == JobCategory::Design) {
                cat = 2;
            } else if (category == JobCategory::Marketing) {
                cat = 3;
            } else if (category == JobCategory::Writing) {
                cat = 4;
            } else if (category == JobCategory::Business) {
                cat = 5;
            } else if (category == JobCategory::Finance) {
                cat = 6;
            } else if (category == JobCategory::Other) {
                cat = 7;
            } else {
                cat = 0;
            }
            // Index the job for efficient search
            let cat_count = self.category_job_count.read(cat);
            self.jobs_by_category.write((cat, cat_count), id);
            self.category_job_count.write(cat, cat_count + 1);

            // Index by experience
            let mut exp = 0;

            match experience_level {
                ExperienceLevel::Entry => { exp = 1; },
                ExperienceLevel::Junior => { exp = 2; },
                ExperienceLevel::Mid => { exp = 3; },
                ExperienceLevel::Senior => { exp = 4; },
                ExperienceLevel::Expert => { exp = 5; },
            }

            let exp_count = self.experience_job_count.read(exp);
            self.jobs_by_experience.write((exp, exp_count), id);
            self.experience_job_count.write(exp, exp_count + 1);

            // Index by location
            let loc_count = self.location_job_count.read(location);
            self.jobs_by_location.write((location, loc_count), id);
            self.location_job_count.write(location, loc_count + 1);

            // Index by duration
            let mut dur = 0;
            match duration {
                JobDuration::OneTime => { dur = 1; },
                JobDuration::ShortTerm => { dur = 2; },
                JobDuration::MediumTerm => { dur = 3; },
                JobDuration::LongTerm => { dur = 4; },
                JobDuration::Ongoing => { dur = 5; },
            }

            let dur_count = self.duration_job_count.read(dur);
            self.jobs_by_duration.write((dur, dur_count), id);
            self.duration_job_count.write(dur, dur_count + 1);

            self.job_counter.write(id);

            self.emit(JobCreated { id, title, author: owner, category });

            id
        }

        // Unified search function
        fn search_jobs(
            self: @ContractState,
            category: Option<JobCategory>,
            min_budget: Option<u256>,
            max_budget: Option<u256>,
            location: Option<felt252>,
            experience_level: Option<ExperienceLevel>,
            duration: Option<JobDuration>,
        ) -> Array<Job> {
            let mut results = ArrayTrait::<Job>::new();
            let total_jobs = self.job_counter.read();

            // If no filters provided, return all open jobs
            let has_filters = category.is_some()
                || min_budget.is_some()
                || max_budget.is_some()
                || location.is_some()
                || experience_level.is_some()
                || duration.is_some();

            if !has_filters {
                let mut i = 1;
                while i <= total_jobs {
                    let job: Job = self.jobs.read(i);
                    if job.status == Status::Open {
                        results.append(job);
                    }
                    i += 1;
                }
                return results;
            }

            // Use most selective filter first for efficiency
            let mut candidate_jobs = ArrayTrait::<u256>::new();
            let mut filter_applied = false;

            // Start with category filter if present
            if let Option::Some(cat) = category {
                // Convert JobCategory to u8 like in create_job
                let mut cat_num: u8 = 0;
                if cat == JobCategory::Technology {
                    cat_num = 1;
                } else if cat == JobCategory::Design {
                    cat_num = 2;
                } else if cat == JobCategory::Marketing {
                    cat_num = 3;
                } else if cat == JobCategory::Writing {
                    cat_num = 4;
                } else if cat == JobCategory::Business {
                    cat_num = 5;
                } else if cat == JobCategory::Finance {
                    cat_num = 6;
                } else if cat == JobCategory::Other {
                    cat_num = 7;
                }

                let count = self.category_job_count.read(cat_num);
                let mut i = 0;
                while i < count {
                    let job_id = self.jobs_by_category.read((cat_num, i));
                    candidate_jobs.append(job_id);
                    i += 1;
                }
                filter_applied = true;
            }

            // If no category filter, start with all jobs
            if !filter_applied {
                let mut i = 1;
                while i <= total_jobs {
                    candidate_jobs.append(i);
                    i += 1;
                }
            }

            // Apply remaining filters
            let mut i = 0;
            while i < candidate_jobs.len() {
                let job_id = *candidate_jobs.at(i);
                let job: Job = self.jobs.read(job_id);

                // Skip if not open
                if job.status != Status::Open {
                    i += 1;
                    continue;
                }

                let mut passes_filters = true;

                // Check budget range
                if let (Option::Some(min), Option::Some(max)) = (min_budget, max_budget) {
                    passes_filters = passes_filters && (job.budget >= min && job.budget_max <= max);
                }
                if let Option::Some(min) = min_budget {
                    passes_filters = passes_filters && job.budget >= min;
                }
                if let Option::Some(max) = max_budget {
                    passes_filters = passes_filters && job.budget_max <= max;
                }

                // Check location
                if let Option::Some(loc) = location {
                    passes_filters = passes_filters && job.location == loc;
                }

                // Check experience level
                if let Option::Some(exp) = experience_level {
                    passes_filters = passes_filters && job.experience_level == exp;
                }

                // Check duration
                if let Option::Some(dur) = duration {
                    passes_filters = passes_filters && job.duration == dur;
                }

                if passes_filters {
                    results.append(job);
                }

                i += 1;
            }

            results
        }

        // Existing functions remain the same...
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

            assert(applicant.address == caller, 'Not your application');

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
            let caller = get_caller_address();
            let mut job = self.get_job(job_id);

            assert(job.owner == caller, 'Not your job');
            assert(job.status == Status::Open, 'Job not open');

            let all_applicants = self.get_all_job_applicants(job_id);
            let total: u256 = all_applicants.len().into();

            let mut assignee: ContractAddress = contract_address_const::<'0x0'>();
            let mut found = false;

            let mut i = 0;
            while i < total {
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
                i += 1;
            }

            assert(found, 'Applicant not found');

            job.status = Status::InProgress;
            self.jobs.write(job_id, job);
            self.emit(JobAssigned { job_id, assignee });
        }

        fn get_all_job_applicants(self: @ContractState, job_id: u256) -> Array<Applicant> {
            let job = self.jobs.read(job_id);
            let mut applicants = ArrayTrait::new();

            let mut i = 1;
            while i <= job.applications {
                let applicant = self.get_applicant(job_id, i);
                applicants.append(applicant);
                i += 1;
            }

            applicants
        }

        fn get_job(self: @ContractState, job_id: u256) -> Job {
            let job = self.jobs.read(job_id);
            job
        }
    }
}
