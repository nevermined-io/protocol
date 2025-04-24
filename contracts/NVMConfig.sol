// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {INVMConfig} from './interfaces/INVMConfig.sol';

import {AccessManagedUUPSUpgradeable} from './proxy/AccessManagedUUPSUpgradeable.sol';
import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';

/**
 * @title Nevermined Config contract
 * @author Nevermined AG
 * @notice This contract serves as the central configuration registry for the Nevermined Protocol
 * @dev NVMConfig implements the following functionality:
 * - Role-based access control for configuration management
 * - Storage for protocol-wide configuration parameters
 * - Registration of contract addresses within the Nevermined ecosystem
 * - Management of network fees collected by the protocol
 *
 * The contract uses OpenZeppelin's AccessControl for role management and
 * implements UUPS (Universal Upgradeable Proxy Standard) pattern for upgradeability.
 */
contract NVMConfig is INVMConfig, AccessControlUpgradeable, AccessManagedUUPSUpgradeable {
    /**
     * @notice Role Owning the Nevermined Config contract
     * @dev Addresses with this role have full control over the contract, including
     * assigning other roles and performing administrative operations
     */
    bytes32 public constant OWNER_ROLE = keccak256('NVM_CONFIG_OWNER');
    /**
     * @notice Role that can change the parameters of the Nevermined Config contract
     * @dev Addresses with this role can modify configuration parameters but have
     * fewer privileges than owners
     */
    bytes32 public constant GOVERNOR_ROLE = keccak256('NVM_GOVERNOR');
    /**
     * @notice Role granted to Smart Contracts registered as Templates (they can execute the template)
     * @dev Used to restrict which contracts can function as agreement templates in the protocol
     */
    bytes32 public constant CONTRACT_TEMPLATE_ROLE = keccak256('NVM_CONTRACT_TEMPLATE');
    /**
     * @notice Role granted to Smart Contracts registered as NVM Conditions (they can fulfill conditions)
     * @dev Used to restrict which contracts can function as conditions within agreement templates
     */
    bytes32 public constant CONTRACT_CONDITION_ROLE = keccak256('NVM_CONTRACT_CONDITION');

    // Storage slot for the NVM configuration namespace following ERC-7201 standard
    // keccak256(abi.encode(uint256(keccak256("nevermined.nvmconfig.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NVM_CONFIG_STORAGE_LOCATION =
        0xd8dc47a566e10bab714c93f5587c29375a3dcfd68f88494af6f1cf90589ce900;

    /**
     * @notice Denominator used for fee calculations, representing 100% with 4 decimal places
     * @dev When calculating fees, divide the fee value by FEE_DENOMINATOR to get the actual percentage
     * Example: 10000 / 1000000 = 0.01 = 1%
     */
    uint256 public constant FEE_DENOMINATOR = 1000000;

    /**
     * @title ParamEntry
     * @notice Represents a configuration parameter in the Nevermined ecosystem
     * @dev This struct stores all relevant information about a configuration parameter
     * @param value The raw bytes value of the parameter that can be decoded by the consumer
     * @param isActive Flag indicating if the parameter is currently active
     * @param lastUpdated Timestamp of when the parameter was last modified
     */
    struct ParamEntry {
        bytes value;
        bool isActive;
        uint256 lastUpdated;
    }

    /// @custom:storage-location erc7201:nevermined.nvmconfig.storage
    /**
     * @title NVMConfigStorage
     * @notice Main storage structure for the Nevermined configuration
     * @dev Uses ERC-7201 for namespaced storage pattern to prevent storage collisions during upgrades
     */
    struct NVMConfigStorage {
        /**
         * @notice Stores all configuration parameters of the protocol
         * @dev Maps parameter names (as bytes32) to their corresponding ParamEntry
         */
        mapping(bytes32 => ParamEntry) configParams;
        /**
         * @notice Registry of contract addresses in the Nevermined ecosystem
         * @dev Maps contract identifiers (as bytes32) to their deployed addresses
         */
        mapping(bytes32 => address) contractsRegistry;
        /**
         * @notice Tracks the latest version of each registered contract
         * @dev Maps contract identifiers to their version numbers
         */
        mapping(bytes32 => uint256) contractsLatestVersion;
        /////// NEVERMINED GOVERNABLE VARIABLES ////////////////////////////////////////////////
        /**
         * @notice The fee charged by Nevermined for using the Service Agreements
         * @dev Integer representing a percentage with 4 decimal places
         * Example: 10000 represents 1.0000% (10000/1000000)
         */
        uint256 networkFee;
        /**
         * @notice The address that receives protocol fees
         * @dev This address collects all fees from service agreement executions
         */
        address feeReceiver;
    }

    /**
     * @notice Initialization function. Sets up the contract with initial roles and permissions
     * @dev This function can only be called once when the proxy contract is initialized
     * @param _owner The address that will have full administrative control over the contract
     * @param _authority The access manager contract that will control upgrade permissions
     * @param _governor The address that will have permission to update configuration parameters
     */
    function initialize(address _owner, IAccessManager _authority, address _governor) external initializer {
        AccessControlUpgradeable.__AccessControl_init();
        AccessControlUpgradeable._grantRole(DEFAULT_ADMIN_ROLE, _owner);
        AccessControlUpgradeable._grantRole(OWNER_ROLE, _owner);
        AccessControlUpgradeable._grantRole(GOVERNOR_ROLE, _governor);
        __AccessManagedUUPSUpgradeable_init(address(_authority));
    }

    ///////////////////////////////////////////////////////////////////////////////////////
    /////// ACCESS CONTROL ////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Modifier restricting access to addresses with either owner or governor roles
     * @dev Reverts with OnlyOwnerOrGovernor error if the address lacks both roles
     * @param _address The address to check for owner or governor role permissions
     */
    modifier onlyOwnerOrGovernor(address _address) {
        if (!hasRole(GOVERNOR_ROLE, _address) && !hasRole(OWNER_ROLE, _address)) {
            revert OnlyOwnerOrGovernor(_address);
        }
        _;
    }

    /**
     * @notice Modifier restricting access to addresses with the governor role
     * @dev Reverts with OnlyGovernor error if the address lacks the governor role
     * @param _address The address to check for governor role permission
     */
    modifier onlyGovernor(address _address) {
        if (!hasRole(GOVERNOR_ROLE, _address)) revert OnlyGovernor(_address);
        _;
    }

    /**
     * @notice Modifier restricting access to addresses with the owner role
     * @dev Reverts with OnlyOwner error if the address lacks the owner role
     * @param _address The address to check for owner role permission
     */
    modifier onlyOwnerRole(address _address) {
        if (!hasRole(OWNER_ROLE, _address)) revert OnlyOwner(_address);
        _;
    }

    /**
     * @notice Grants governor role to an address
     * @dev Only callable by addresses with the OWNER_ROLE
     * @dev Emits ConfigPermissionsChange event when successful
     * @param _address The address to be granted the governor role
     */
    function grantGovernor(address _address) external onlyOwnerRole(msg.sender) {
        _grantRole(GOVERNOR_ROLE, _address);
        emit ConfigPermissionsChange(_address, GOVERNOR_ROLE, true);
    }

    /**
     * @notice Revokes governor role from an address
     * @dev Only callable by addresses with the OWNER_ROLE
     * @dev Emits ConfigPermissionsChange event when successful
     * @param _address The address from which to revoke the governor role
     */
    function revokeGovernor(address _address) external onlyOwnerRole(msg.sender) {
        _revokeRole(GOVERNOR_ROLE, _address);
        emit ConfigPermissionsChange(_address, GOVERNOR_ROLE, false);
    }

    /**
     * @notice Checks if an address has the governor role
     * @dev Useful for front-ends or other contracts to verify permissions
     * @param _address The address to check
     * @return Boolean indicating whether the address has the governor role
     */
    function isGovernor(address _address) external view returns (bool) {
        return hasRole(GOVERNOR_ROLE, _address);
    }

    /**
     * @notice Checks if an address has the owner role
     * @dev Useful for front-ends or other contracts to verify permissions
     * @param _address The address to check
     * @return Boolean indicating whether the address has the owner role
     */
    function isOwner(address _address) external view returns (bool) {
        return hasRole(OWNER_ROLE, _address);
    }

    /**
     * @notice Public wrapper around AccessControl's hasRole function
     * @dev Allows external contracts to check if an address has a specific role
     * @param _address The address to check
     * @param _role The role identifier to check for
     * @return Boolean indicating whether the address has the specified role
     */
    function hasRole(address _address, bytes32 _role) external view returns (bool) {
        return super.hasRole(_role, _address);
    }

    /**
     * @notice Grants template role to a contract address
     * @dev Only callable by addresses with the GOVERNOR_ROLE
     * @dev Emits ConfigPermissionsChange event when successful
     * @dev Template contracts can execute agreement templates in the Nevermined ecosystem
     * @param _address The contract address to be granted the template role
     */
    function grantTemplate(address _address) external onlyGovernor(msg.sender) {
        _grantRole(CONTRACT_TEMPLATE_ROLE, _address);
        emit ConfigPermissionsChange(_address, CONTRACT_TEMPLATE_ROLE, true);
    }

    /**
     * @notice Revokes template role from a contract address
     * @dev Only callable by addresses with the GOVERNOR_ROLE
     * @dev Emits ConfigPermissionsChange event when successful
     * @dev Once revoked, the contract can no longer execute agreement templates
     * @param _address The contract address from which to revoke the template role
     */
    function revokeTemplate(address _address) external onlyGovernor(msg.sender) {
        _revokeRole(CONTRACT_TEMPLATE_ROLE, _address);
        emit ConfigPermissionsChange(_address, CONTRACT_TEMPLATE_ROLE, false);
    }

    /**
     * @notice Checks if an address has the contract template role
     * @dev Useful for front-ends or other contracts to verify if a contract can execute templates
     * @param _address The address to check
     * @return Boolean indicating whether the address has the contract template role
     */
    function isTemplate(address _address) external view returns (bool) {
        return hasRole(CONTRACT_TEMPLATE_ROLE, _address);
    }

    /**
     * @notice Grants condition role to a contract address
     * @dev Only callable by addresses with the GOVERNOR_ROLE
     * @dev Emits ConfigPermissionsChange event when successful
     * @dev Condition contracts can fulfill conditions within agreement templates
     * @param _address The contract address to be granted the condition role
     */
    function grantCondition(address _address) external onlyGovernor(msg.sender) {
        _grantRole(CONTRACT_CONDITION_ROLE, _address);
        emit ConfigPermissionsChange(_address, CONTRACT_CONDITION_ROLE, true);
    }

    /**
     * @notice Revokes condition role from a contract address
     * @dev Only callable by addresses with the GOVERNOR_ROLE
     * @dev Emits ConfigPermissionsChange event when successful
     * @dev Once revoked, the contract can no longer fulfill conditions
     * @param _address The contract address from which to revoke the condition role
     */
    function revokeCondition(address _address) external onlyGovernor(msg.sender) {
        _revokeRole(CONTRACT_CONDITION_ROLE, _address);
        emit ConfigPermissionsChange(_address, CONTRACT_CONDITION_ROLE, false);
    }

    /**
     * @notice Checks if an address has the contract condition role
     * @dev Useful for front-ends or other contracts to verify if a contract can fulfill conditions
     * @param _address The address to check
     * @return Boolean indicating whether the address has the contract condition role
     */
    function isCondition(address _address) external view returns (bool) {
        return hasRole(CONTRACT_CONDITION_ROLE, _address);
    }

    ///////////////////////////////////////////////////////////////////////////////////////
    /////// CONFIG FUNCTIONS //////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Sets the network fee and fee receiver address for the Nevermined protocol
     * @dev Only a governor address can call this function
     * @dev Emits NeverminedConfigChange events for both fee and receiver updates
     * @dev The fee is expressed as a value between 0 and 1,000,000 (representing 0% to 100%)
     *
     * @param _networkFee The fee percentage charged by Nevermined (in parts per 1,000,000)
     * @param _feeReceiver The address that will receive collected fees
     *
     * @custom:error InvalidNetworkFee Thrown if the fee is outside the valid range (0-1,000,000)
     * @custom:error InvalidFeeReceiver Thrown if a fee is set but the receiver is the zero address
     */
    function setNetworkFees(uint256 _networkFee, address _feeReceiver) external virtual onlyGovernor(msg.sender) {
        NVMConfigStorage storage $ = _getNVMConfigStorage();

        if (_networkFee < 0 || _networkFee > 1000000) {
            revert InvalidNetworkFee(_networkFee);
        }

        if (_networkFee > 0 && _feeReceiver == address(0)) {
            revert InvalidFeeReceiver(_feeReceiver);
        }

        $.networkFee = _networkFee;
        $.feeReceiver = _feeReceiver;
        emit NeverminedConfigChange(msg.sender, keccak256('networkFee'), abi.encodePacked(_networkFee));
        emit NeverminedConfigChange(msg.sender, keccak256('feeReceiver'), abi.encodePacked(_feeReceiver));
    }

    /**
     * @notice Retrieves the current network fee percentage
     * @dev The returned value must be divided by FEE_DENOMINATOR to get the actual percentage
     * @return Current network fee in parts per 1,000,000 (e.g., 10000 = 1%)
     */
    function getNetworkFee() external view returns (uint256) {
        return _getNVMConfigStorage().networkFee;
    }

    /**
     * @notice Retrieves the address that receives protocol fees
     * @dev If this returns the zero address and fees are set, fees cannot be collected
     * @return The current fee receiver address
     */
    function getFeeReceiver() external view returns (address) {
        return _getNVMConfigStorage().feeReceiver;
    }

    /**
     * @notice Returns the denominator used for fee calculations
     * @dev This is a constant value used as the denominator when calculating fee percentages
     * @return The fee denominator constant (1,000,000 representing 100% with 4 decimal places)
     */
    function getFeeDenominator() external pure returns (uint256) {
        return FEE_DENOMINATOR;
    }

    /**
     * @notice Sets a parameter in the Nevermined configuration
     * @dev Only an account with GOVERNOR_ROLE can call this function
     * @dev Emits NeverminedConfigChange event on parameter update
     * @dev Parameters are generic key-value pairs that can store any configuration data
     *
     * @param _paramName The name/key of the parameter to set (as bytes32)
     * @param _value The value to set for the parameter (as arbitrary bytes)
     */
    function setParameter(bytes32 _paramName, bytes memory _value) external virtual onlyGovernor(msg.sender) {
        NVMConfigStorage storage $ = _getNVMConfigStorage();

        $.configParams[_paramName].value = _value;
        $.configParams[_paramName].isActive = true;
        $.configParams[_paramName].lastUpdated = block.timestamp;
        emit NeverminedConfigChange(msg.sender, _paramName, _value);
    }

    /**
     * @notice Retrieves a parameter from the Nevermined configuration
     * @dev Returns the complete parameter entry including value, status and timestamp
     *
     * @param _paramName The name/key of the parameter to retrieve
     * @return value The parameter's raw bytes value
     * @return isActive Whether the parameter is currently active
     * @return lastUpdated Timestamp of when the parameter was last updated
     */
    function getParameter(bytes32 _paramName)
        external
        view
        returns (bytes memory value, bool isActive, uint256 lastUpdated)
    {
        NVMConfigStorage storage $ = _getNVMConfigStorage();

        return (
            $.configParams[_paramName].value,
            $.configParams[_paramName].isActive,
            $.configParams[_paramName].lastUpdated
        );
    }

    /**
     * @notice Disables a parameter in the Nevermined configuration
     * @dev Only an account with GOVERNOR_ROLE can call this function
     * @dev Emits NeverminedConfigChange event on parameter update
     * @dev Does nothing if the parameter is already inactive
     *
     * @param _paramName The name/key of the parameter to disable
     */
    function disableParameter(bytes32 _paramName) external virtual onlyGovernor(msg.sender) {
        NVMConfigStorage storage $ = _getNVMConfigStorage();

        if ($.configParams[_paramName].isActive) {
            $.configParams[_paramName].isActive = false;
            $.configParams[_paramName].lastUpdated = block.timestamp;
            emit NeverminedConfigChange(msg.sender, _paramName, $.configParams[_paramName].value);
        }
    }

    /**
     * @notice Checks if a parameter exists and is active in the Nevermined configuration
     * @dev A parameter is considered to exist only if it is marked as active
     *
     * @param _paramName The name/key of the parameter to check
     * @return Boolean indicating whether the parameter exists and is active
     */
    function parameterExists(bytes32 _paramName) external view returns (bool) {
        return _getNVMConfigStorage().configParams[_paramName].isActive;
    }

    /**
     * @notice Internal function to access the contract's namespaced storage
     * @dev Uses ERC-7201 storage pattern to prevent storage collisions during upgrades
     * @return $ A reference to the NVMConfigStorage struct at the designated storage slot
     */
    function _getNVMConfigStorage() internal pure returns (NVMConfigStorage storage $) {
        assembly ("memory-safe") {
            $.slot := NVM_CONFIG_STORAGE_LOCATION
        }
    }
}
