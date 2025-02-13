// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Lock {
  uint256 public unlockTime;
  address payable public owner;

  event Withdrawal(uint256 amount, uint256 when);

  /// Unlock time: `unlockTime` should be in the future
  /// @param unlockTime The time when the contract will be unlocked
  /// @param currentTime The current time
  error UnlockError(uint256 unlockTime, uint256 currentTime);

  /// It's not possible to witdraw before the unlock time
  /// @param unlockTime The time when the contract will be unlocked
  /// @param currentTime The current time
  error UnableToWithdrawYet(uint256 unlockTime, uint256 currentTime);

  /// Only the owner can call this function, but `sender` is not the owner
  /// @param sender The address of the account calling this function
  error OnlyOwner(address sender);

  constructor(uint256 _unlockTime) payable {
    if (block.timestamp >= _unlockTime) {
      revert UnlockError(_unlockTime, block.timestamp);
    }
    unlockTime = _unlockTime;
    owner = payable(msg.sender);
  }

  function withdraw() public {
    // Uncomment this line, and the import of "hardhat/console.sol", to print a log in your terminal
    // console.log("Unlock time is %o and block timestamp is %o", unlockTime, block.timestamp);

    if (block.timestamp < unlockTime) {
      revert UnableToWithdrawYet(unlockTime, block.timestamp);
    }

    if (msg.sender != owner) {
      revert OnlyOwner(msg.sender);
    }

    emit Withdrawal(address(this).balance, block.timestamp);

    owner.transfer(address(this).balance);
  }
}
