// SPDX-License-Identifier: MIT
// Tests for PaymentRouter contract

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.bool import TRUE, FALSE

@contract_interface
namespace IPaymentRouter:
    func add_supported_token(token_address: felt):
    end
    func remove_supported_token(token_address: felt):
    end
    func process_payment(token: felt, recipient: felt, amount: Uint256) -> (success: felt):
    end
    func is_token_supported(token_address: felt) -> (is_supported: felt):
    end
    func get_platform_fee() -> (percentage: felt):
    end
    func get_platform_wallet() -> (wallet: felt):
    end
end

@contract_interface
namespace IERC20:
    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end
    func transferFrom(sender: felt, recipient: felt, amount: Uint256) -> (success: felt):
    end
    func balanceOf(account: felt) -> (balance: Uint256):
    end
end

@external
func test_payment_router_initialization{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}():
    // Test initialization values
    let (fee) = IPaymentRouter.get_platform_fee()
    assert fee = 5  // 5% platform fee

    let (wallet) = IPaymentRouter.get_platform_wallet()
    assert wallet = 123  // Test platform wallet address
    return ()
end

@external
func test_token_management{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}():
    // Test adding token
    let test_token = 456  // Test token address
    IPaymentRouter.add_supported_token(test_token)
    
    let (is_supported) = IPaymentRouter.is_token_supported(test_token)
    assert is_supported = TRUE

    // Test removing token
    IPaymentRouter.remove_supported_token(test_token)
    
    let (is_supported_after) = IPaymentRouter.is_token_supported(test_token)
    assert is_supported_after = FALSE
    return ()
end

@external
func test_payment_processing{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}():
    // Setup test values
    let test_token = 456
    let recipient = 789
    let amount = Uint256(1000, 0)  // Test amount

    // Add token support
    IPaymentRouter.add_supported_token(test_token)

    // Process payment
    let (success) = IPaymentRouter.process_payment(test_token, recipient, amount)
    assert success = TRUE

    return ()
end

@external
func test_payment_with_fees{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}():
    // Setup test values
    let test_token = 456
    let sender = get_caller_address()
    let recipient = 789
    let amount = Uint256(1000, 0)  // Test amount
    let expected_fee = Uint256(50, 0)  // 5% of 1000

    // Add token support
    IPaymentRouter.add_supported_token(test_token)

    // Process payment
    let (success) = IPaymentRouter.process_payment(test_token, recipient, amount)
    assert success = TRUE

    // Verify balances
    let (platform_wallet) = IPaymentRouter.get_platform_wallet()
    let (platform_balance) = IERC20.balanceOf(test_token, platform_wallet)
    assert platform_balance = expected_fee

    return ()
end