// SPDX-License-Identifier: MIT
// Payment Router contract for StarkHive

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.bool import TRUE, FALSE

// Interface for ERC20 tokens
@contract_interface
namespace IERC20:
    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end
    func transferFrom(sender: felt, recipient: felt, amount: Uint256) -> (success: felt):
    end
    func balanceOf(account: felt) -> (balance: Uint256):
    end
end

// Storage variables
@storage_var
func supported_tokens(token_address: felt) -> (is_supported: felt):
end

@storage_var
func platform_fee_percentage() -> (percentage: felt):
end

@storage_var
func platform_wallet() -> (address: felt):
end

@storage_var
func owner() -> (address: felt):
end

// Events
@event
func TokenAdded(token_address: felt):
end

@event
func TokenRemoved(token_address: felt):
end

@event
func PaymentProcessed(
    token: felt,
    sender: felt,
    recipient: felt,
    amount: Uint256,
    fee_amount: Uint256
):
end

// Constructor
@constructor
func constructor(
    owner_address: felt,
    platform_wallet_: felt,
    initial_fee_percentage: felt
):
    owner.write(owner_address)
    platform_wallet.write(platform_wallet_)
    platform_fee_percentage.write(initial_fee_percentage)
    return ()
end

// Only owner modifier
@private
func assert_only_owner{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}():
    let (caller) = get_caller_address()
    let (current_owner) = owner.read()
    assert caller = current_owner
    return ()
end

// Add supported token
@external
func add_supported_token{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(token_address: felt):
    assert_only_owner()
    supported_tokens.write(token_address, TRUE)
    TokenAdded.emit(token_address)
    return ()
end

// Remove supported token
@external
func remove_supported_token{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(token_address: felt):
    assert_only_owner()
    supported_tokens.write(token_address, FALSE)
    TokenRemoved.emit(token_address)
    return ()
end

// Process payment
@external
func process_payment{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr
}(
    token: felt,
    recipient: felt,
    amount: Uint256
) -> (success: felt):
    alloc_locals

    // Check if token is supported
    let (is_supported) = supported_tokens.read(token)
    assert is_supported = TRUE

    // Calculate fee
    let (fee_percentage) = platform_fee_percentage.read()
    let fee_amount = Uint256(amount.low * fee_percentage / 100, 0)
    
    // Get platform wallet
    let (platform_address) = platform_wallet.read()
    
    // Transfer fee to platform wallet
    let (success_fee) = IERC20.transferFrom(token, get_caller_address(), platform_address, fee_amount)
    assert success_fee = TRUE

    // Calculate recipient amount
    let recipient_amount = Uint256(amount.low - fee_amount.low, 0)
    
    // Transfer remaining amount to recipient
    let (success_transfer) = IERC20.transferFrom(token, get_caller_address(), recipient, recipient_amount)
    assert success_transfer = TRUE

    PaymentProcessed.emit(token, get_caller_address(), recipient, amount, fee_amount)
    return (TRUE)
end

// View functions
@view
func is_token_supported(token_address: felt) -> (is_supported: felt):
    let (is_supported) = supported_tokens.read(token_address)
    return (is_supported)
end

@view
func get_platform_fee() -> (percentage: felt):
    let (percentage) = platform_fee_percentage.read()
    return (percentage)
end

@view
func get_platform_wallet() -> (wallet: felt):
    let (wallet) = platform_wallet.read()
    return (wallet)
end