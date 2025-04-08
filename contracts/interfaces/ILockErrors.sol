// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

/**
 * @title ILockErrors
 * @notice Error definitions for Lock-related contracts
 */
interface ILockErrors {
    /// Unlock time: `unlockTime` should be in the future
    /// @param unlockTime The time when the contract will be unlocked
    /// @param currentTime The current time
    error UnlockError(uint256 unlockTime, uint256 currentTime);

    /// It's not possible to witdraw before the unlock time
    /// @param unlockTime The time when the contract will be unlocked
    /// @param currentTime The current time
    error UnableToWithdrawYet(uint256 unlockTime, uint256 currentTime);

    /**
     * Event emitted on withdrawals from lock contract
     * @param amount amount withdrawn
     * @param when timestamp of withdrawal
     */
    event Withdrawal(uint256 amount, uint256 when);
}
