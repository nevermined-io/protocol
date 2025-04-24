// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

/**
 * @title Nevermined Configuration Interface
 * @author Nevermined AG
 * @notice Interface defining the core configuration management functionality for the Nevermined Protocol
 * @dev This interface establishes the contract functions and events required for maintaining
 * protocol-wide configuration, managing roles, and controlling access to administrative features
 */
interface INVMConfig {
    /**
     * @notice Event that is emitted when a configuration parameter is changed
     * @param whoChanged The address of the governor changing the parameter
     * @param parameter The hash of the name of the parameter changed
     * @param value The new value of the parameter
     */
    event NeverminedConfigChange(address indexed whoChanged, bytes32 indexed parameter, bytes value);

    /**
     * @notice Event emitted when permission roles are granted or revoked
     * @param addressPermissions The address receiving or losing permissions
     * @param permissions The role given or taken
     * @param grantPermissions If true means the permissions are granted if false means they are revoked
     */
    event ConfigPermissionsChange(
        address indexed addressPermissions, bytes32 indexed permissions, bool grantPermissions
    );

    /**
     * @notice Error thrown when a non-owner address attempts to access an owner-restricted function
     * @param sender The address of the account calling this function
     */
    error OnlyOwner(address sender);

    /**
     * @notice Error thrown when a non-governor address attempts to access a governor-restricted function
     * @param sender The address of the account calling this function
     */
    error OnlyGovernor(address sender);

    /**
     * @notice Error thrown when an address without owner or governor role attempts to access a restricted function
     * @param sender The address of the account calling this function
     */
    error OnlyOwnerOrGovernor(address sender);

    /**
     * @notice Error thrown when an invalid network fee is provided
     * @dev Fee must be between 0 and FEE_DENOMINATOR (1,000,000, representing 100%)
     * @param networkFee The invalid network fee that was provided
     */
    error InvalidNetworkFee(uint256 networkFee);

    /**
     * @notice Error thrown when an invalid fee receiver address is provided
     * @dev The fee receiver cannot be the zero address when fees are enabled
     * @param feeReceiver The invalid fee receiver address that was provided
     */
    error InvalidFeeReceiver(address feeReceiver);

    /**
     * @notice Error thrown when an invalid address is provided to a function
     * @param _address The invalid address that was provided
     */
    error InvalidAddress(address _address);

    /**
     * @notice Error thrown when a non-template address attempts to access template-restricted functions
     * @param sender The address of the account calling this function
     */
    error OnlyTemplate(address sender);

    /**
     * @notice Error thrown when an address without template or condition role attempts to access a restricted function
     * @param sender The address of the account calling this function
     */
    error OnlyTemplateOrCondition(address sender);

    /**
     * @notice Error thrown when an address without the required role attempts to access a role-restricted function
     * @param sender The address of the account calling this function
     * @param role The role required to call this function
     */
    error InvalidRole(address sender, bytes32 role);

    /**
     * @notice Retrieves the current network fee percentage
     * @dev The returned value must be divided by FEE_DENOMINATOR to get the actual percentage
     * @return Current network fee in parts per 1,000,000 (e.g., 10000 = 1%)
     */
    function getNetworkFee() external view returns (uint256);

    /**
     * @notice Retrieves the address that receives protocol fees
     * @dev If this returns the zero address and fees are set, fees cannot be collected
     * @return The current fee receiver address
     */
    function getFeeReceiver() external view returns (address);

    /**
     * @notice Returns the denominator used for fee calculations
     * @dev This is a constant value used as the denominator when calculating fee percentages
     * @return The fee denominator constant (1,000,000 representing 100% with 4 decimal places)
     */
    function getFeeDenominator() external pure returns (uint256);

    /**
     * @notice Checks if an address has the contract template role
     * @dev Used to verify if a contract can execute templates in the Nevermined ecosystem
     * @param _address The address to check
     * @return Boolean indicating whether the address has the contract template role
     */
    function isTemplate(address _address) external view returns (bool);

    /**
     * @notice Checks if an address has the contract condition role
     * @dev Used to verify if a contract can fulfill conditions within agreement templates
     * @param _address The address to check
     * @return Boolean indicating whether the address has the contract condition role
     */
    function isCondition(address _address) external view returns (bool);

    /**
     * @notice Checks if an address has the governor role
     * @dev Governors can modify configuration parameters but have fewer privileges than owners
     * @param _address The address to check
     * @return Boolean indicating whether the address has the governor role
     */
    function isGovernor(address _address) external view returns (bool);

    /**
     * @notice Checks if an address has the owner role
     * @dev Owners have full control over the contract, including assigning other roles
     * @param _address The address to check
     * @return Boolean indicating whether the address has the owner role
     */
    function isOwner(address _address) external view returns (bool);

    /**
     * @notice Checks if an address has a specific role
     * @dev General-purpose role verification function
     * @param _address The address to check
     * @param _role The role identifier to check for
     * @return Boolean indicating whether the address has the specified role
     */
    function hasRole(address _address, bytes32 _role) external view returns (bool);
}
