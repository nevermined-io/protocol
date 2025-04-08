// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

/**
 * @title IConfigErrors
 * @notice Error definitions for Config-related contracts
 */
interface IConfigErrors {
    /// Only a valid governor address can call this function, but `sender` is not part of the governors
    /// @param sender The address of the account calling this function
    error OnlyGovernor(address sender);

    /// Only the owner can call this function, but `sender` is not the owner
    /// @param sender The address of the account calling this function
    error OnlyOwner(address sender);

    /// Fee must be between 0 and 100 percent but a `networkFee` was provided
    /// @param networkFee The network fee to configure
    error InvalidNetworkFee(uint256 networkFee);

    /// The network fee receiver can not be the zero address or an invalid address but `feeReceiver` was provided
    /// @param feeReceiver The fee receiver address to configure
    error InvalidFeeReceiver(address feeReceiver);

    /// The address provided (_address) is not valid
    /// @param _address The _address given as parameter
    error InvalidAddress(address _address);

    /// The contract version provided (_newVersion) is not higher than the latest version (_latestVersion)
    /// @param _newVersion The _newVersion given as parameter
    /// @param _latestVersion The _latestVersion of the contract already registered
    error InvalidContractVersion(uint256 _newVersion, uint256 _latestVersion);

    /// Only a valid registered template address can call this function, but `sender` is not part of the list of registered Templates
    /// @param sender The address of the account calling this function
    error OnlyTemplate(address sender);

    /// Only a valid registered template or condition address can call this function, but `sender` is not part of the list of registered Templates or Conditions
    /// @param sender The address of the account calling this function
    error OnlyTemplateOrCondition(address sender);

    /**
     * @notice Event that is emitted when a parameter is changed
     * @param whoChanged the address of the governor changing the parameter
     * @param parameter the hash of the name of the parameter changed
     * @param value the new value of the parameter
     */
    event NeverminedConfigChange(
        address indexed whoChanged,
        bytes32 indexed parameter,
        bytes value
    );

    /**
     * Event emitted when some permissions are granted or revoked
     * @param addressPermissions the address receving or losing permissions
     * @param permissions the role given or taken
     * @param grantPermissions if true means the permissions are granted if false means they are revoked
     */
    event ConfigPermissionsChange(
        address indexed addressPermissions,
        bytes32 indexed permissions,
        bool grantPermissions
    );

    /**
     * Event emitted when a contract is registered in the Nevermined Config contract
     * @param registeredBy the address registering the new contract
     * @param name the name of the contract registered
     * @param contractAddress the address of the contract registered
     * @param version The version of the contract registered
     */
    event ContractRegistered(
        address indexed registeredBy,
        bytes32 indexed name,
        address indexed contractAddress,
        uint256 version
    );
}
