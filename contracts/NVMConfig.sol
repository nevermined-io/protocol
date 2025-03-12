// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {INVMConfig} from './interfaces/INVMConfig.sol';
import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';

/**
 * @title Nevermined Config contract
 * @author @aaitor
 * @notice This contract stores all the relevant configuration used by the Nevermined Protocol
 */
contract NVMConfig is INVMConfig, AccessControlUpgradeable {
  /**
   * @notice Role Owning the Nevermined Config contract
   */
  bytes32 public constant OWNER_ROLE = keccak256('NVM_CONFIG_OWNER');
  /**
   * @notice Role that can change the parameters of the Nevermined Config contract
   */
  bytes32 public constant GOVERNOR_ROLE = keccak256('NVM_GOVERNOR');
  /**
   * @notice Role granted to Smart Contracts registered as Templates (they can execute the template)
   */
  bytes32 public constant CONTRACT_TEMPLATE_ROLE = keccak256('NVM_CONTRACT_TEMPLATE');
  /**
   * @notice Role granted to Smart Contracts registered as NVM Conditions (they can fulfill conditions)
   */
  bytes32 public constant CONTRACT_CONDITION_ROLE = keccak256('NVM_CONTRACT_CONDITION');


  /**
   * The struct that represents a parameter in the Nevermined Config contract
   * @param value the value of the parameter
   * @param isActive if the parameter is active or not
   * @param lastUpdated the timestamp of the last time the parameter was updated
   */
  struct ParamEntry {
    bytes value;
    bool isActive;
    uint256 lastUpdated;
  }

  /// Mapping of the parameters in the Nevermined Config contract
  mapping(bytes32 => ParamEntry) public configParams;

  /// Mapping of contracts registered in the Nevermined Config contract
  mapping(bytes32 => address) public contractsRegistry;

  /// Mapping of contracts latest versionnregistered in the Nevermined Config contract
  mapping(bytes32 => uint256) public contractsLatestVersion;

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
  

  ///////////////////////////////////////////////////////////////////////////////////////
  /////// NEVERMINED GOVERNABLE VARIABLES ////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////

  // @notice The fee charged by Nevermined for using the Service Agreements.
  // Integer representing a 2 decimal number. i.e 350 means a 3.5% fee
  uint256 public networkFee;

  // @notice The address that will receive the fee charged by Nevermined per transaction
  // See `marketplaceFee`
  address public feeReceiver;

  uint256 constant public FEE_DENOMINATOR = 1000000;


  /**
   * Initialization function
   * @param _owner The address owning the contract
   * @param _governor The first governor address able to setup configuration parameters
   */
  function initialize(address _owner, address _governor) public initializer {
    AccessControlUpgradeable.__AccessControl_init();
    AccessControlUpgradeable._grantRole(OWNER_ROLE, _owner);
    AccessControlUpgradeable._grantRole(GOVERNOR_ROLE, _governor);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  /////// ACCESS CONTROL ////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * Modifier restricting access to only governors addresses
   * @param _address the address to validate if has the governor role
   */
  modifier onlyGovernor(address _address) {
    if (!hasRole(GOVERNOR_ROLE, _address)) revert OnlyGovernor(_address);
    _;
  }

  /**
   * Modifier restricting access to only owner addresses
   * @param _address the address to validate if has the owner role
   */
  modifier onlyOwner(address _address) {
    if (!hasRole(OWNER_ROLE, _address)) revert OnlyOwner(_address);
    _;
  }

  /**
   * Function to grant the governor role to an address.
   * @notice Only an owner address can call this function.
   * @param _address the address to grant the governor role
   */
  function grantGovernor(address _address) external onlyOwner(msg.sender) {
    _grantRole(GOVERNOR_ROLE, _address);
    emit ConfigPermissionsChange(_address, GOVERNOR_ROLE, true);
  }

  /**
   * Function to revoke the governor role to an address.
   * @notice Only an owner address can call this function.
   * @param _address the address to revoke the governor role
   */
  function revokeGovernor(address _address) external onlyOwner(msg.sender) {
    _revokeRole(GOVERNOR_ROLE, _address);
    emit ConfigPermissionsChange(_address, GOVERNOR_ROLE, false);
  }

  /**
   * Checks if an address has the governor role
   * @param _address the address to check if has the governor role
   * @return true if the address has the governor role, false otherwise
   */
  function isGovernor(address _address) external view returns (bool) {
    return hasRole(GOVERNOR_ROLE, _address);
  }

  /**
   * Function to grant the governor role to an address.
   * @notice Only an owner address can call this function.
   * @param _address the address to grant the governor role
   */
  function grantTemplate(address _address) external onlyGovernor(msg.sender) {
    _grantRole(CONTRACT_TEMPLATE_ROLE, _address);
    emit ConfigPermissionsChange(_address, CONTRACT_TEMPLATE_ROLE, true);
  }

  /**
   * Function to revoke the governor role to an address.
   * @notice Only an owner address can call this function.
   * @param _address the address to revoke the governor role
   */
  function revokeTemplate(address _address) external onlyGovernor(msg.sender) {
    _revokeRole(CONTRACT_TEMPLATE_ROLE, _address);
    emit ConfigPermissionsChange(_address, CONTRACT_TEMPLATE_ROLE, false);
  }

  /**
   * Checks if an address has the contract template role
   * @param _address the address to check if has the contract template role
   * @return true if the address has the contract template role, false otherwise
   */
  function isTemplate(address _address) external view returns (bool) {
    return hasRole(CONTRACT_TEMPLATE_ROLE, _address);
  }

  /**
   * Function to grant the condition role to an address.
   * @notice Only an owner address can call this function.
   * @param _address the address to grant the condition role
   */
  function grantCondition(address _address) external onlyGovernor(msg.sender) {
    _grantRole(CONTRACT_CONDITION_ROLE, _address);
    emit ConfigPermissionsChange(_address, CONTRACT_CONDITION_ROLE, true);
  }

  /**
   * Function to revoke the contract condition role to an address.
   * @notice Only an owner address can call this function.
   * @param _address the address to revoke the role
   */
  function revokeCondition(address _address) external onlyGovernor(msg.sender) {
    _revokeRole(CONTRACT_CONDITION_ROLE, _address);
    emit ConfigPermissionsChange(_address, CONTRACT_CONDITION_ROLE, false);
  }

  /**
   * Checks if an address has the contract condition role
   * @param _address the address to check if has the contract condition role
   * @return true if the address has the contract condition role, false otherwise
   */
  function isCondition(address _address) external view returns (bool) {
    return hasRole(CONTRACT_CONDITION_ROLE, _address);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  /////// CONFIG FUNCTIONS //////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////

  /**
   * It allows to set the network fee charged by Nevermined and the address receiving the fee
   * for using the Service Agreements.
   * The fees must be between 0 (0 percent) and 1000000 (100 percent).
   * @notice Only a governor address can call this function.
   * @param _networkFee The fee charged by Nevermined for using the Service Agreements
   * @param _feeReceiver The address receiving the Nevermined fee
   */
  function setNetworkFees(
    uint256 _networkFee,
    address _feeReceiver
  ) external virtual onlyGovernor(msg.sender) {
    if (_networkFee < 0 || _networkFee > 1000000) {
      revert InvalidNetworkFee(_networkFee);
    }

    if (_networkFee > 0 && _feeReceiver == address(0)) {
      revert InvalidFeeReceiver(_feeReceiver);
    }

    networkFee = _networkFee;
    feeReceiver = _feeReceiver;
    emit NeverminedConfigChange(
      msg.sender,
      keccak256('networkFee'),
      abi.encodePacked(_networkFee)
    );
    emit NeverminedConfigChange(
      msg.sender,
      keccak256('feeReceiver'),
      abi.encodePacked(_feeReceiver)
    );
  }

  /**
   * It returns the network fee charged by Nevermined for using the Service Agreements.
   * @return the network fee charged by Nevermined
   */
  function getNetworkFee() external view returns (uint256) {
    return networkFee;
  }

  /**
   * It returns the address receiving the fee charged by Nevermined for using the Service Agreements.
   * @return the address receiving the fee charged by Nevermined
   */
  function getFeeReceiver() external view returns (address) {
    return feeReceiver;
  }

  function getFeeDenominator() external pure returns (uint256) {
    return FEE_DENOMINATOR;
  }

  function setParameter(
    bytes32 _paramName,
    bytes memory _value
  ) external virtual onlyGovernor(msg.sender) {
    configParams[_paramName].value = _value;
    configParams[_paramName].isActive = true;
    configParams[_paramName].lastUpdated = block.timestamp;
    emit NeverminedConfigChange(msg.sender, _paramName, _value);
  }

  function getParameter(
    bytes32 _paramName
  )
    external
    view
    returns (bytes memory value, bool isActive, uint256 lastUpdated)
  {
    return (
      configParams[_paramName].value,
      configParams[_paramName].isActive,
      configParams[_paramName].lastUpdated
    );
  }

  function disableParameter(
    bytes32 _paramName
  ) external virtual onlyGovernor(msg.sender) {
    if (configParams[_paramName].isActive) {
      configParams[_paramName].isActive = false;
      configParams[_paramName].lastUpdated = block.timestamp;
      emit NeverminedConfigChange(
        msg.sender,
        _paramName,
        configParams[_paramName].value
      );
    }
  }

  function parameterExists(bytes32 _paramName) external view returns (bool) {
    return configParams[_paramName].isActive;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  /////// DNS FUNCTIONS /////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////

  function registerContract(
    bytes32 _name,
    address _address    
  ) public virtual onlyGovernor(msg.sender) {
    uint256 latestVersion = this.getContractLatestVersion(keccak256(abi.encode(_name)));
    this.registerContract(_name, _address, latestVersion + 1);
  }

  function registerContract(
    bytes32 _name,
    address _address,
    uint256 _version    
  ) public virtual onlyGovernor(msg.sender) {

    if (_address == address(0)) {
      revert InvalidAddress(_address);
    }
    uint256 latestVersion = this.getContractLatestVersion(_name);
    if (_version <= latestVersion) {
      revert InvalidContractVersion(_version, latestVersion);
    }

    bytes32 _id = keccak256(abi.encode(_name, _version));
    contractsRegistry[_id] = _address;
    contractsLatestVersion[keccak256(abi.encode(_name))] = _version;
    emit ContractRegistered(msg.sender, _name, _address, _version);
  }

  function resolveContract(
    bytes32 _name   
  ) external view returns (address contractAddress)
  {
    uint256 latestVersion = this.getContractLatestVersion(keccak256(abi.encode(_name)));
    return this.resolveContract(_name, latestVersion);    
  }

  function resolveContract(
    bytes32 _name,
    uint256 _version    
  ) external view returns (address contractAddress)
  {
    bytes32 _id = keccak256(abi.encode(_name, _version));
    return contractsRegistry[_id];
  }

  function getContractLatestVersion(
    bytes32 _name
  ) external view returns (uint256 version)
  {
    return contractsLatestVersion[keccak256(abi.encode(_name))];
  }
}
