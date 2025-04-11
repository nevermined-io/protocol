// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

/**
 * @title IAccessManagedUUPSUpgradeable
 * @notice Interface for the AccessManagedUUPSUpgradeable contract
 */
interface IAccessManagedUUPSUpgradeable {
    /**
     * @notice Emitted when an upgrade is authorized
     * @param caller The address that initiated the upgrade (msg.sender)
     * @param newImplementation The address of the new implementation
     */
    event UpgradeAuthorized(address indexed caller, address indexed newImplementation);
}
