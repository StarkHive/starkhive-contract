use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starkhive_contract::base::types::{ApplicationStatus, Job, Status};
use starkhive_contract::contracts::MockUSDC::{IExternalDispatcher, IExternalDispatcherTrait};
use starkhive_contract::interfaces::IJobs::{IJobsDispatcher, IJobsDispatcherTrait};
use starknet::{ContractAddress, contract_address, contract_address_const, get_block_timestamp};


fn setup() -> (ContractAddress, ContractAddress) {
    let declare_result = declare("Jobs");
    assert(declare_result.is_ok(), 'Contract declaration failed');

    let erc20_contract = deploy_erc20();
    let erc20_address = erc20_contract.contract_address;
    let contract_class = declare_result.unwrap().contract_class();
    let mut calldata = array![];

    let deploy_result = contract_class.deploy(@calldata);
    assert(deploy_result.is_ok(), 'Contract deployment failed');

    let (contract_address, _) = deploy_result.unwrap();

    (contract_address, erc20_address)
}

fn deploy_erc20() -> IExternalDispatcher {
    let owner: ContractAddress = contract_address_const::<'owner'>();

    let contract_class = declare("MockUsdc").unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@array![owner.into(), owner.into()]).unwrap();

    IExternalDispatcher { contract_address }
}

#[test]
fn test_job() {
    let (contract_address, erc20_address) = setup();
    let dispatcher = IJobsDispatcher { contract_address };

    // Test input values
    let user: ContractAddress = contract_address_const::<'user'>();
    let title: felt252 = 'Cairo Developer';
    let description: ByteArray = "Build Cairo dApps";
    let budget: u256 = 500;
    let deadline = get_block_timestamp() + 84600;
    let requirements: ByteArray = "2years Cairo experience";

    let sender: ContractAddress = contract_address_const::<'owner'>();
    start_cheat_caller_address(contract_address, sender);

    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
    let token_idispatcher = IExternalDispatcher { contract_address: erc20_address };

    token_idispatcher.mint(user, 20000);

    stop_cheat_caller_address(contract_address);

    let balanceb4 = token_dispatcher.balance_of(user);

    start_cheat_caller_address(erc20_address, user);

    token_dispatcher.approve(contract_address, 10000);

    stop_cheat_caller_address(contract_address);

    // Ensure the caller is the admin
    start_cheat_caller_address(contract_address, user);
    // Call create_job
    let job_id = dispatcher
        .create_job(
            erc20_address, title, description.clone(), budget, deadline, requirements.clone(), user,
        );

    // Validate that the coujobrse ID is correctly incremented
    assert(job_id == 1, 'job_id should start from 1');

    let contract_balance = token_dispatcher.balance_of(contract_address);

    let balanceafter = token_dispatcher.balance_of(user);
    assert(balanceafter == (balanceb4 - budget), 'balance error');

    // Retrieve the job to verify it was stored correctly
    let job = dispatcher.get_job(job_id);

    assert(job.title == title, 'job title mismatch');
    assert(contract_balance == budget, 'Contract did not get funds');
    assert(job.owner == user, 'job owner mismatch');
    assert(job.description == description, 'job description mismatch');
    assert(job.budget == budget, 'job budget mismatch');
    assert(job.deadline == deadline, 'job deadline mismatch');
    assert(job.requirements == requirements, 'job requirements mismatch');
    assert(job.status == Status::Open, 'Job Status mismatch');
    assert(job.deadline == deadline, 'job deadline mismatch');
    assert(job.created_at == get_block_timestamp(), 'job created mismatch');
}
#[test]
fn test_cancel_job() {
    let (contract_address, erc20_address) = setup();
    let dispatcher = IJobsDispatcher { contract_address };

    // Test input values
    let user: ContractAddress = contract_address_const::<'user'>();
    let title: felt252 = 'Cairo Developer';
    let description: ByteArray = "Build Cairo dApps";
    let budget: u256 = 500;
    let deadline = get_block_timestamp() + 84600;
    let requirements: ByteArray = "2years Cairo experience";

    let sender: ContractAddress = contract_address_const::<'owner'>();
    start_cheat_caller_address(contract_address, sender);

    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
    let token_idispatcher = IExternalDispatcher { contract_address: erc20_address };

    token_idispatcher.mint(user, 20000);

    stop_cheat_caller_address(contract_address);

    let balanceb4 = token_dispatcher.balance_of(user);

    start_cheat_caller_address(erc20_address, user);

    token_dispatcher.approve(contract_address, 10000);

    stop_cheat_caller_address(contract_address);

    // Ensure the caller is the admin
    start_cheat_caller_address(contract_address, user);
    // Call create_job
    let job_id = dispatcher
        .create_job(
            erc20_address, title, description.clone(), budget, deadline, requirements.clone(), user,
        );

    start_cheat_caller_address(erc20_address, contract_address);
    token_dispatcher.approve(user, budget);
    stop_cheat_caller_address(contract_address);
    // Validate that the coujobrse ID is correctly incremented
    assert(job_id == 1, 'job_id should start from 1');

    start_cheat_caller_address(contract_address, user);
    dispatcher.cancel_job(erc20_address, job_id);
    stop_cheat_caller_address(contract_address);

    let balanceafter = token_dispatcher.balance_of(user);
    assert(balanceafter == balanceb4, 'balance error');
    stop_cheat_caller_address(contract_address);
    // Retrieve the job to verify it was stored correctly
    let job = dispatcher.get_job(job_id);

    assert(job.status == Status::Cancelled, 'Job Status mismatch');
}

#[test]
fn test_assign_job() {
    let (contract_address, erc20_address) = setup();
    let dispatcher = IJobsDispatcher { contract_address };

    // Test input values
    let job_creator: ContractAddress = contract_address_const::<'user'>();
    let applicant: ContractAddress = contract_address_const::<'applicant'>();
    let title: felt252 = 'Cairo Developer';
    let description: ByteArray = "Build Cairo dApps";
    let budget: u256 = 500;
    let deadline = get_block_timestamp() + 84600;
    let requirements: ByteArray = "2years Cairo experience";
    let qualification: ByteArray = "2years Cairo experience";

    // Ensure the caller is the admin

    let sender: ContractAddress = contract_address_const::<'owner'>();
    start_cheat_caller_address(contract_address, sender);

    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
    let token_idispatcher = IExternalDispatcher { contract_address: erc20_address };

    token_idispatcher.mint(job_creator, 20000);
    let balanceb4 = token_dispatcher.balance_of(job_creator);

    start_cheat_caller_address(erc20_address, job_creator);
    token_dispatcher.approve(contract_address, 10000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, job_creator);
    // Call create_job
    let job_id = dispatcher
        .create_job(
            erc20_address,
            title,
            description.clone(),
            budget,
            deadline,
            requirements.clone(),
            job_creator,
        );

    // Validate that the coujobrse ID is correctly incremented

    stop_cheat_caller_address(contract_address);

    assert(job_id == 1, 'job_id should start from 1');
    let balanceafter = token_dispatcher.balance_of(job_creator);
    assert(balanceafter == (balanceb4 - budget), 'balance error');

    cheat_caller_address(contract_address, applicant, CheatSpan::Indefinite);

    let applicant_id = dispatcher.apply_for_job(job_id, qualification);

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, job_creator, CheatSpan::Indefinite);

    dispatcher.assign_job(job_id, applicant_id);

    stop_cheat_caller_address(contract_address);

    // Retrieve the job to verify it was stored correctly
    let job = dispatcher.get_job(job_id);

    let applicant_info = dispatcher.get_applicant(job_id, applicant_id);

    assert(job.applicant == applicant, 'applicant mismatch');
    assert(
        applicant_info.application_status == ApplicationStatus::Assigned,
        'Applicant status mismatch',
    );
    assert(applicant_info.job_id == job_id, 'job id mismatch');
    assert(job.status == Status::InProgress, 'Job Status mismatch');
}

#[test]
fn test_multiple_apply_job() {
    let (contract_address, erc20_address) = setup();
    let dispatcher = IJobsDispatcher { contract_address };

    // Test input values
    let job_creator: ContractAddress = contract_address_const::<'user'>();
    let applicant: ContractAddress = contract_address_const::<'applicant'>();
    let title: felt252 = 'Cairo Developer';
    let description: ByteArray = "Build Cairo dApps";
    let budget: u256 = 500;
    let deadline = get_block_timestamp() + 84600;
    let requirements: ByteArray = "2years Cairo experience";
    let qualification: ByteArray = "2years Cairo experience";
    let applicant1: ContractAddress = contract_address_const::<'applicant1'>();
    let applicant2: ContractAddress = contract_address_const::<'applicant2'>();

    // Ensure the caller is the admin

    let sender: ContractAddress = contract_address_const::<'owner'>();
    start_cheat_caller_address(contract_address, sender);

    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
    let token_idispatcher = IExternalDispatcher { contract_address: erc20_address };

    token_idispatcher.mint(job_creator, 20000);
    let balanceb4 = token_dispatcher.balance_of(job_creator);

    start_cheat_caller_address(erc20_address, job_creator);
    token_dispatcher.approve(contract_address, 10000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, job_creator);
    // Call create_job
    let job_id = dispatcher
        .create_job(
            erc20_address,
            title,
            description.clone(),
            budget,
            deadline,
            requirements.clone(),
            job_creator,
        );
    stop_cheat_caller_address(contract_address);
    // Validate that the coujobrse ID is correctly incremented
    assert(job_id == 1, 'job_id should start from 1');
    let balanceafter = token_dispatcher.balance_of(job_creator);
    assert(balanceafter == (balanceb4 - budget), 'balance error');

    cheat_caller_address(contract_address, applicant, CheatSpan::Indefinite);

    dispatcher.apply_for_job(job_id, qualification.clone());

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant1, CheatSpan::Indefinite);

    dispatcher.apply_for_job(job_id, qualification.clone());

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant2, CheatSpan::Indefinite);

    dispatcher.apply_for_job(job_id, qualification);

    stop_cheat_caller_address(contract_address);

    // Retrieve the job to verify it was stored correctly
    let job = dispatcher.get_all_job_applicants(job_id);
    assert(job.len() == 3, 'Get All jobs failed');
}

#[test]
fn test_submit_job() {
    let (contract_address, erc20_address) = setup();
    let dispatcher = IJobsDispatcher { contract_address };

    // Test input values
    let job_creator: ContractAddress = contract_address_const::<'user'>();
    let applicant: ContractAddress = contract_address_const::<'applicant'>();
    let title: felt252 = 'Cairo Developer';
    let description: ByteArray = "Build Cairo dApps";
    let budget: u256 = 500;
    let deadline = get_block_timestamp() + 84600;
    let requirements: ByteArray = "2years Cairo experience";
    let qualification: ByteArray = "2years Cairo experience";

    let applicant1: ContractAddress = contract_address_const::<'applicant1'>();
    let applicant2: ContractAddress = contract_address_const::<'applicant2'>();

    // Ensure the caller is the admin

    let sender: ContractAddress = contract_address_const::<'owner'>();
    start_cheat_caller_address(contract_address, sender);

    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
    let token_idispatcher = IExternalDispatcher { contract_address: erc20_address };

    token_idispatcher.mint(job_creator, 20000);
    let balanceb4 = token_dispatcher.balance_of(job_creator);

    start_cheat_caller_address(erc20_address, job_creator);
    token_dispatcher.approve(contract_address, 10000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, job_creator);
    // Call create_job
    let job_id = dispatcher
        .create_job(
            erc20_address,
            title,
            description.clone(),
            budget,
            deadline,
            requirements.clone(),
            job_creator,
        );
    stop_cheat_caller_address(contract_address);

    // Validate that the coujobrse ID is correctly incremented
    assert(job_id == 1, 'job_id should start from 1');
    let balanceafter = token_dispatcher.balance_of(job_creator);
    assert(balanceafter == (balanceb4 - budget), 'balance error');

    cheat_caller_address(contract_address, applicant, CheatSpan::Indefinite);

    let applicant0 = dispatcher.apply_for_job(job_id, qualification.clone());

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant1, CheatSpan::Indefinite);

    stop_cheat_caller_address(contract_address);

    let _applicant1 = dispatcher.apply_for_job(job_id, qualification.clone());

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant2, CheatSpan::Indefinite);

    let _applicant2 = dispatcher.apply_for_job(job_id, qualification);

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, job_creator, CheatSpan::Indefinite);
    dispatcher.assign_job(job_id, applicant0);
    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant, CheatSpan::Indefinite);
    dispatcher.submit_job(job_id, applicant0);
    stop_cheat_caller_address(contract_address);

    let job = dispatcher.get_job(job_id);

    let lucky_guy = dispatcher.get_applicant(job_id, applicant0);

    assert(job.status == Status::Reviewing, 'status update error');
    assert(job.applicant == applicant, 'job assignment error');
    assert(lucky_guy.application_status == ApplicationStatus::Reviewing, 'Lucky guy error');
}

#[test]
fn test_approve_job() {
    let (contract_address, erc20_address) = setup();
    let dispatcher = IJobsDispatcher { contract_address };

    // Test input values
    let job_creator: ContractAddress = contract_address_const::<'user'>();
    let applicant: ContractAddress = contract_address_const::<'applicant'>();
    let title: felt252 = 'Cairo Developer';
    let description: ByteArray = "Build Cairo dApps";
    let budget: u256 = 500;
    let deadline = get_block_timestamp() + 84600;
    let requirements: ByteArray = "2years Cairo experience";
    let qualification: ByteArray = "2years Cairo experience";

    let applicant1: ContractAddress = contract_address_const::<'applicant1'>();
    let applicant2: ContractAddress = contract_address_const::<'applicant2'>();

    // Ensure the caller is the admin

    let sender: ContractAddress = contract_address_const::<'owner'>();
    start_cheat_caller_address(contract_address, sender);

    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
    let token_idispatcher = IExternalDispatcher { contract_address: erc20_address };

    token_idispatcher.mint(job_creator, 20000);
    let balanceb4 = token_dispatcher.balance_of(job_creator);

    start_cheat_caller_address(erc20_address, job_creator);
    token_dispatcher.approve(contract_address, 10000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, job_creator);
    // Call create_job
    let job_id = dispatcher
        .create_job(
            erc20_address,
            title,
            description.clone(),
            budget,
            deadline,
            requirements.clone(),
            job_creator,
        );
    stop_cheat_caller_address(contract_address);
    let balanceafter = token_dispatcher.balance_of(job_creator);

    // Validate that the coujobrse ID is correctly incremented
    assert(job_id == 1, 'job_id should start from 1');
    assert(balanceafter == (balanceb4 - budget), 'balance error');
    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant, CheatSpan::Indefinite);

    let applicant0 = dispatcher.apply_for_job(job_id, qualification.clone());

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant1, CheatSpan::Indefinite);

    stop_cheat_caller_address(contract_address);

    let _applicant1 = dispatcher.apply_for_job(job_id, qualification.clone());

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant2, CheatSpan::Indefinite);

    let _applicant2 = dispatcher.apply_for_job(job_id, qualification);

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, job_creator, CheatSpan::Indefinite);
    dispatcher.assign_job(job_id, applicant0);
    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant, CheatSpan::Indefinite);
    dispatcher.submit_job(job_id, applicant0);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(erc20_address, contract_address);
    token_dispatcher.approve(job_creator, budget);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, job_creator);
    dispatcher.approve_submission(erc20_address, job_id, applicant0);
    stop_cheat_caller_address(contract_address);

    let job = dispatcher.get_job(job_id);

    let lucky_guy = dispatcher.get_applicant(job_id, applicant0);

    let balanceafter = token_dispatcher.balance_of(applicant);
    assert(balanceafter == budget, 'balance error');

    assert(job.status == Status::Completed, 'status update error');
    assert(job.applicant == applicant, 'job assignment error');
    assert(lucky_guy.application_status == ApplicationStatus::Accepted, 'Lucky guy error');
}

#[test]
fn test_reject_submission() {
    let (contract_address, erc20_address) = setup();
    let dispatcher = IJobsDispatcher { contract_address };

    // Test input values
    let job_creator: ContractAddress = contract_address_const::<'user'>();
    let applicant: ContractAddress = contract_address_const::<'applicant'>();
    let title: felt252 = 'Cairo Developer';
    let description: ByteArray = "Build Cairo dApps";
    let budget: u256 = 500;
    let deadline = get_block_timestamp() + 84600;
    let requirements: ByteArray = "2years Cairo experience";
    let qualification: ByteArray = "2years Cairo experience";

    let applicant1: ContractAddress = contract_address_const::<'applicant1'>();
    let applicant2: ContractAddress = contract_address_const::<'applicant2'>();

    // Ensure the caller is the admin

    let sender: ContractAddress = contract_address_const::<'owner'>();
    start_cheat_caller_address(contract_address, sender);

    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
    let token_idispatcher = IExternalDispatcher { contract_address: erc20_address };

    token_idispatcher.mint(job_creator, 20000);
    let balanceb4 = token_dispatcher.balance_of(job_creator);

    start_cheat_caller_address(erc20_address, job_creator);
    token_dispatcher.approve(contract_address, 10000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, job_creator);
    // Call create_job
    let job_id = dispatcher
        .create_job(
            erc20_address,
            title,
            description.clone(),
            budget,
            deadline,
            requirements.clone(),
            job_creator,
        );
    stop_cheat_caller_address(contract_address);

    // Validate that the coujobrse ID is correctly incremented
    assert(job_id == 1, 'job_id should start from 1');
    let balanceafter = token_dispatcher.balance_of(job_creator);
    assert(balanceafter == (balanceb4 - budget), 'balance error');

    cheat_caller_address(contract_address, applicant, CheatSpan::Indefinite);

    let applicant0 = dispatcher.apply_for_job(job_id, qualification.clone());

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant1, CheatSpan::Indefinite);

    stop_cheat_caller_address(contract_address);

    let _applicant1 = dispatcher.apply_for_job(job_id, qualification.clone());

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant2, CheatSpan::Indefinite);

    let _applicant2 = dispatcher.apply_for_job(job_id, qualification);

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, job_creator, CheatSpan::Indefinite);
    dispatcher.assign_job(job_id, applicant0);
    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant, CheatSpan::Indefinite);
    dispatcher.submit_job(job_id, applicant0);
    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, job_creator, CheatSpan::Indefinite);
    dispatcher.reject_submission(job_id, applicant0);
    stop_cheat_caller_address(contract_address);

    let job = dispatcher.get_job(job_id);

    let lucky_guy = dispatcher.get_applicant(job_id, applicant0);

    assert(job.status == Status::Rejected, 'status update error');
    assert(job.applicant == applicant, 'job assignment error');
    assert(lucky_guy.application_status == ApplicationStatus::Rejected, 'Lucky guy error');
}


#[test]
fn test_request_changes() {
    let (contract_address, erc20_address) = setup();
    let dispatcher = IJobsDispatcher { contract_address };

    // Test input values
    let job_creator: ContractAddress = contract_address_const::<'user'>();
    let applicant: ContractAddress = contract_address_const::<'applicant'>();
    let title: felt252 = 'Cairo Developer';
    let description: ByteArray = "Build Cairo dApps";
    let budget: u256 = 500;
    let deadline = get_block_timestamp() + 84600;
    let requirements: ByteArray = "2years Cairo experience";
    let qualification: ByteArray = "2years Cairo experience";

    let applicant1: ContractAddress = contract_address_const::<'applicant1'>();
    let applicant2: ContractAddress = contract_address_const::<'applicant2'>();
    // Ensure the caller is the admin

    let sender: ContractAddress = contract_address_const::<'owner'>();
    start_cheat_caller_address(contract_address, sender);

    let token_dispatcher = IERC20Dispatcher { contract_address: erc20_address };
    let token_idispatcher = IExternalDispatcher { contract_address: erc20_address };

    token_idispatcher.mint(job_creator, 20000);

    start_cheat_caller_address(erc20_address, job_creator);
    token_dispatcher.approve(contract_address, 10000);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, job_creator);

    // Call create_job
    let job_id = dispatcher
        .create_job(
            erc20_address,
            title,
            description.clone(),
            budget,
            deadline,
            requirements.clone(),
            job_creator,
        );
    stop_cheat_caller_address(contract_address);

    // Validate that the coujobrse ID is correctly incremented

    cheat_caller_address(contract_address, applicant, CheatSpan::Indefinite);

    let applicant0 = dispatcher.apply_for_job(job_id, qualification.clone());

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant1, CheatSpan::Indefinite);

    stop_cheat_caller_address(contract_address);

    let _applicant1 = dispatcher.apply_for_job(job_id, qualification.clone());

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant2, CheatSpan::Indefinite);

    let _applicant2 = dispatcher.apply_for_job(job_id, qualification);

    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, job_creator, CheatSpan::Indefinite);
    dispatcher.assign_job(job_id, applicant0);
    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, applicant, CheatSpan::Indefinite);
    dispatcher.submit_job(job_id, applicant0);
    stop_cheat_caller_address(contract_address);

    cheat_caller_address(contract_address, job_creator, CheatSpan::Indefinite);
    dispatcher.request_changes(job_id, applicant0);
    stop_cheat_caller_address(contract_address);

    let job = dispatcher.get_job(job_id);

    let lucky_guy = dispatcher.get_applicant(job_id, applicant0);

    assert(job.status == Status::Disputed, 'status update error');
    assert(job.applicant == applicant, 'job assignment error');
    assert(lucky_guy.application_status == ApplicationStatus::Pending, 'Lucky guy error');
}

