// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {INVMConfig} from './interfaces/INVMConfig.sol';
import {AccessManagerUpgradeable} from '@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {ContextUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol';
import {MulticallUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol';

/**
 * @title Nevermined Config contract
 * @author @aaitor
 * @notice This contract stores all the relevant configuration used by the Nevermined Protocol
 */
contract NVMConfig is INVMConfig, Initializable, ContextUpgradeable, MulticallUpgradeable, AccessManagerUpgradeable {
  
  /**
   * @notice Role constants for AccessManager
   * Note: ADMIN_ROLE (0) and PUBLIC_ROLE (2^64-1) are built into AccessManagerUpgradeable
   */
  
  /**
   * @notice Role Owning the Nevermined Config contract
   */
  uint64 public constant OWNER_ROLE = 1;
  /**
   * @notice Role that can change the parameters of the Nevermined Config contract
   */
  uint64 public constant GOVERNOR_ROLE = 2;
  /**
   * @notice Role granted to Smart Contracts registered as Templates (they can execute the template)
   */
  uint64 public constant CONTRACT_TEMPLATE_ROLE = 3;
  /**
   * @notice Role granted to Smart Contracts registered as NVM Conditions (they can fulfill conditions)
   */
  uint64 public constant CONTRACT_CONDITION_ROLE = 4;


  /**
   * @notice Emitted when a contract is registered
   * @param contractName The name of the contract
   * @param contractAddress The address of the contract
   * @param version The version of the contract
   */
  event ContractRegistered(
    bytes32 indexed contractName,
    address indexed contractAddress,
    uint256 version
  );

  /**
   * @notice Emitted when a configuration parameter is changed
   * @param _param The name of the parameter
   * @param _value The value of the parameter
   */
  event NeverminedConfigChange(bytes32 indexed _param, bytes _value);

  /**
   * @notice Emitted when a permission is changed
   * @param _address The address of the account
   * @param _role The role of the account
   * @param _allowed Whether the account is allowed or not
   */
  event ConfigPermissionsChange(
    address indexed _address,
    bytes32 indexed _role,
    bool _allowed
  );

  /**
   * @notice The network fee amount
   */
  uint256 private networkFee;

  /**
   * @notice The address that receives the network fee
   */
  address private feeReceiver;

  /**
   * @notice The denominator for the network fee
   */
  uint256 private constant FEE_DENOMINATOR = 1000000;

  /**
   * @notice Mapping of parameter name to parameter value
   */
  mapping(bytes32 => bytes) private parameters;

  /**
   * @notice Mapping of contract name to contract address
   */
  mapping(bytes32 => mapping(uint256 => address)) private contracts;

  /**
   * @notice Mapping of contract name to latest version
   */
  mapping(bytes32 => uint256) private contractsLatestVersion;


  /**
   * @notice Initialization function
   * @dev Initializes the contract with the owner and governor
   * @param _owner The address owning the contract
   * @param _governor The first governor address able to setup configuration parameters
   */
  function initialize(address _owner, address _governor) public initializer {
    __Context_init();
    __Multicall_init();
    __AccessManager_init(_owner);
    
    // Grant governor role to the specified governor
    _grantRole(GOVERNOR_ROLE, _governor, 0, 0);
    // Explicitly grant OWNER_ROLE to the owner
    _grantRole(OWNER_ROLE, _owner, 0, 0);
  }


  ///////////////////////////////////////////////////////////////////////////////////////
  /////// ACCESS CONTROL ////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * Modifier restricting access to only governors addresses
   * @param _address the address to validate if has the governor role
   */
  modifier onlyGovernor(address _address) {
    (bool immediate, ) = AccessManagerUpgradeable.hasRole(GOVERNOR_ROLE, _address);
    if (!immediate) revert OnlyGovernor(_address);
    _;
  }

  /**
   * Modifier restricting access to only owner addresses
   * @param _address the address to validate if has the owner role
   */
  modifier onlyOwner(address _address) {
    (bool immediate, ) = AccessManagerUpgradeable.hasRole(OWNER_ROLE, _address);
    if (!immediate) revert OnlyOwner(_address);
    _;
  }

  /**
   * Function to grant the governor role to an address.
   * @notice Only an owner address can call this function.
   * @param _address the address to grant the governor role
   */
  function grantGovernor(address _address) external onlyOwner(msg.sender) {
    _grantRole(GOVERNOR_ROLE, _address, 0, 0);
    emit ConfigPermissionsChange(_address, bytes32(uint256(GOVERNOR_ROLE)), true);
  }

  /**
   * Function to revoke the governor role to an address.
   * @notice Only an owner address can call this function.
   * @param _address the address to revoke the governor role
   */
  function revokeGovernor(address _address) external onlyOwner(msg.sender) {
    _revokeRole(GOVERNOR_ROLE, _address);
    emit ConfigPermissionsChange(_address, bytes32(uint256(GOVERNOR_ROLE)), false);
  }

  /**
   * Checks if an address has the governor role
   * @param _address the address to check if has the governor role
   * @return true if the address has the governor role, false otherwise
   */
  function isGovernor(address _address) external view returns (bool) {
    (bool immediate, ) = AccessManagerUpgradeable.hasRole(GOVERNOR_ROLE, _address);
    return immediate;
  }

  /**
   * Checks if an address has the owner role
   * @param _address the address to check if has the owner role
   * @return true if the address has the owner role, false otherwise
   */
  function isOwner(address _address) external view returns (bool) {
    (bool immediate, ) = AccessManagerUpgradeable.hasRole(OWNER_ROLE, _address);
    return immediate;
  }

  // Custom implementation to maintain compatibility with INVMConfig interface
  function hasRole(address _address, bytes32 _role) external view override returns (bool) {
    (bool immediate, ) = AccessManagerUpgradeable.hasRole(uint64(uint256(_role)), _address);
    return immediate;
  }
  
  /**
   * Function to grant the template role to an address.
   * @notice Only a governor address can call this function.
   * @param _address the address to grant the template role
   */
  function grantTemplate(address _address) external onlyGovernor(msg.sender) {
    _grantRole(CONTRACT_TEMPLATE_ROLE, _address, 0, 0);
    emit ConfigPermissionsChange(_address, bytes32(uint256(CONTRACT_TEMPLATE_ROLE)), true);
  }
  
  // Compatibility function for tests with bytes32 role
  function grantRoleBytes32(bytes32 role, address account) public {
    (bool immediate, ) = AccessManagerUpgradeable.hasRole(0, msg.sender); // ADMIN_ROLE = 0
    if (!immediate) revert OnlyOwner(msg.sender);
    _grantRole(uint64(uint256(role)), account, 0, 0);
  }

  /**
   * Function to revoke the template role to an address.
   * @notice Only a governor address can call this function.
   * @param _address the address to revoke the template role
   */
  function revokeTemplate(address _address) external onlyGovernor(msg.sender) {
    _revokeRole(CONTRACT_TEMPLATE_ROLE, _address);
    emit ConfigPermissionsChange(_address, bytes32(uint256(CONTRACT_TEMPLATE_ROLE)), false);
  }

  /**
   * Checks if an address has the contract template role
   * @param _address the address to check if has the contract template role
   * @return true if the address has the contract template role, false otherwise
   */
  function isTemplate(address _address) external view returns (bool) {
    (bool immediate, ) = AccessManagerUpgradeable.hasRole(CONTRACT_TEMPLATE_ROLE, _address);
    return immediate;
  }

  /**
   * Function to grant the condition role to an address.
   * @notice Only a governor address can call this function.
   * @param _address the address to grant the condition role
   */
  function grantCondition(address _address) external onlyGovernor(msg.sender) {
    _grantRole(CONTRACT_CONDITION_ROLE, _address, 0, 0);
    emit ConfigPermissionsChange(_address, bytes32(uint256(CONTRACT_CONDITION_ROLE)), true);
  }

  /**
   * Function to revoke the contract condition role to an address.
   * @notice Only a governor address can call this function.
   * @param _address the address to revoke the role
   */
  function revokeCondition(address _address) external onlyGovernor(msg.sender) {
    _revokeRole(CONTRACT_CONDITION_ROLE, _address);
    emit ConfigPermissionsChange(_address, bytes32(uint256(CONTRACT_CONDITION_ROLE)), false);
  }

  /**
   * Checks if an address has the contract condition role
   * @param _address the address to check if has the contract condition role
   * @return true if the address has the contract condition role, false otherwise
   */
  function isCondition(address _address) external view returns (bool) {
    (bool immediate, ) = AccessManagerUpgradeable.hasRole(CONTRACT_CONDITION_ROLE, _address);
    return immediate;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  /////// NETWORK FEES /////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @notice Sets the network fee and the fee receiver
   * @param _networkFee The network fee amount
   * @param _feeReceiver The address that receives the network fee
   */
  function setNetworkFees(
    uint256 _networkFee,
    address _feeReceiver
  ) external onlyGovernor(msg.sender) {
    if (_networkFee > FEE_DENOMINATOR) revert InvalidNetworkFee(_networkFee);
    if (_feeReceiver == address(0)) revert InvalidFeeReceiver(_feeReceiver);

    networkFee = _networkFee;
    feeReceiver = _feeReceiver;

    emit NeverminedConfigChange(
      bytes32('networkFee'),
      abi.encodePacked(_networkFee)
    );
    emit NeverminedConfigChange(
      bytes32('feeReceiver'),
      abi.encodePacked(_feeReceiver)
    );
  }

  /**
   * @notice Gets the network fee amount
   * @return The network fee amount
   */
  function getNetworkFee() external view returns (uint256) {
    return networkFee;
  }

  /**
   * @notice Gets the fee receiver address
   * @return The fee receiver address
   */
  function getFeeReceiver() external view returns (address) {
    return feeReceiver;
  }

  /**
   * @notice Gets the fee denominator
   * @return The fee denominator
   */
  function getFeeDenominator() external pure returns (uint256) {
    return FEE_DENOMINATOR;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  /////// PARAMETERS ///////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @notice Sets a parameter
   * @param _param The parameter name
   * @param _value The parameter value
   */
  function setParameter(
    bytes32 _param,
    bytes calldata _value
  ) external onlyGovernor(msg.sender) {
    parameters[_param] = _value;
    emit NeverminedConfigChange(_param, _value);
  }

  /**
   * @notice Gets a parameter
   * @param _param The parameter name
   * @return The parameter value and whether it exists
   */
  function getParameter(bytes32 _param) external view returns (bytes memory, bool) {
    return (parameters[_param], parameters[_param].length > 0);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  /////// CONTRACTS REGISTRY ///////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * @notice Registers a contract
   * @param _name The contract name
   * @param _address The contract address
   * @param _version The contract version
   */
  function registerContract(
    bytes32 _name,
    address _address,
    uint256 _version
  ) external onlyGovernor(msg.sender) {
    if (_address == address(0)) revert InvalidAddress(_address);
    if (_version <= contractsLatestVersion[_name])
      revert InvalidContractVersion(_version, contractsLatestVersion[_name]);

    contracts[_name][_version] = _address;
    contractsLatestVersion[_name] = _version;

    emit ContractRegistered(_name, _address, _version);
  }

  /**
   * @notice Registers a contract
   * @param _name The contract name
   * @param _address The contract address
   */
  function registerContract(
    bytes32 _name,
    address _address
  ) external onlyGovernor(msg.sender) {
    if (_address == address(0)) revert InvalidAddress(_address);

    uint256 _version = contractsLatestVersion[_name] + 1;
    contracts[_name][_version] = _address;
    contractsLatestVersion[_name] = _version;

    emit ContractRegistered(_name, _address, _version);
  }

  /**
   * @notice Resolves a contract
   * @param _name The contract name
   * @param _version The contract version
   * @return The contract address
   */
  function resolveContract(
    bytes32 _name,
    uint256 _version
  ) external view returns (address) {
    return contracts[_name][_version];
  }

  /**
   * @notice Resolves a contract
   * @param _name The contract name
   * @return The contract address
   */
  function resolveContract(bytes32 _name) external view returns (address) {
    return contracts[_name][contractsLatestVersion[_name]];
  }
}
