// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

/**
 * @title ITokenErrors
 * @notice Error definitions for Token-related contracts
 */
interface ITokenErrors {
    /// Only an account with the right role can access this function
    /// @param sender The address of the account calling this function
    /// @param role The role required to call this function
    error InvalidRole(address sender, bytes32 role);
}
