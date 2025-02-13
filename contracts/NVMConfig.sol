// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';

contract NVMConfig is AccessControlUpgradeable {
  /**
   * @notice Role Owning the Nevermined Config contract
   */
  bytes32 public constant OWNER_ROLE = keccak256('NVM_CONFIG_OWNER');
  /**
   * @notice Role that can change the parameters of the Nevermined Config contract
   */
  bytes32 public constant GOVERNOR_ROLE = keccak256('NVM_GOVERNOR');

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

  mapping(bytes32 => ParamEntry) public configParams;

  /**
   * @notice Event that is emitted when a parameter is changed
   * @param _whoChanged the address of the governor changing the parameter
   * @param _parameter the hash of the name of the parameter changed
   */
  event NeverminedConfigChange(
    address indexed _whoChanged,
    bytes32 indexed _parameter,
    bytes _value
  );

  /**
   * Event emitted when some permissions are granted or revoked
   * @param _address the address receving or losing permissions
   * @param _permissions the role given or taken
   * @param _grantPermissions if true means the permissions are granted if false means they are revoked
   */
  event ConfigPermissionsChange(
    address indexed _address,
    bytes32 indexed _permissions,
    bool _grantPermissions
  );

  /// Only the owner can call this function, but `sender` is not the owner
  /// @param sender The address of the account calling this function
  error OnlyOwner(address sender);

  /// Only a valid governor address can call this function, but `sender` is not part of the governors
  /// @param sender The address of the account calling this function
  error OnlyGovernor(address sender);

  /// Fee must be between 0 and 100 percent but a `networkFee` was provided
  /// @param networkFee The network fee to configure
  error InvalidNetworkFee(uint256 networkFee);

  /// The network fee receiver can not be the zero address or an invalid address but `feeReceiver` was provided
  /// @param feeReceiver The fee receiver address to configure
  error InvalidFeeReceiver(address feeReceiver);

  ///////////////////////////////////////////////////////////////////////////////////////
  /////// NEVERMINED GOVERNABLE VARIABLES ////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////

  // @notice The fee charged by Nevermined for using the Service Agreements.
  // Integer representing a 2 decimal number. i.e 350 means a 3.5% fee
  uint256 public networkFee;

  // @notice The address that will receive the fee charged by Nevermined per transaction
  // See `marketplaceFee`
  address public feeReceiver;

  function initialize(address _owner, address _governor) public initializer {
    AccessControlUpgradeable.__AccessControl_init();
    AccessControlUpgradeable._grantRole(OWNER_ROLE, _owner);
    AccessControlUpgradeable._grantRole(GOVERNOR_ROLE, _governor);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  /////// ACCESS CONTROL ////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////
  modifier onlyGovernor(address _address) {
    if (!hasRole(GOVERNOR_ROLE, _address)) revert OnlyGovernor(_address);
    _;
  }

  modifier onlyOwner(address _address) {
    if (!hasRole(OWNER_ROLE, _address)) revert OnlyOwner(_address);
    _;
  }

  function grantGovernor(address _address) external onlyOwner(msg.sender) {
    _grantRole(GOVERNOR_ROLE, _address);
    emit ConfigPermissionsChange(_address, GOVERNOR_ROLE, true);
  }

  function revokeGovernor(address _address) external onlyOwner(msg.sender) {
    _revokeRole(GOVERNOR_ROLE, _address);
    emit ConfigPermissionsChange(_address, GOVERNOR_ROLE, false);
  }

  function isGovernor(address _address) external view returns (bool) {
    return hasRole(GOVERNOR_ROLE, _address);
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  /////// CONFIG FUNCTIONS //////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////

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

  function getNetworkFee() external view returns (uint256) {
    return networkFee;
  }

  function getFeeReceiver() external view returns (address) {
    return feeReceiver;
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
}
