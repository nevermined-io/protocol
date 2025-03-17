// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {ERC4626Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol';
import {INVMConfig} from './interfaces/INVMConfig.sol';
import {IVault} from './interfaces/IVault.sol';


contract PaymentsVault is ERC4626Upgradeable, IVault {

  /**
   * @notice Role allowing to deposit assets into the Vault
  */
  bytes32 public constant DEPOSITOR_ROLE = keccak256('VAULT_DEPOSITOR_ROLE');

  /**
   * @notice Role allowing to withdraw assets from the Vault
  */
  bytes32 public constant WITHDRAW_ROLE = keccak256('VAULT_WITHDRAW_ROLE');

  INVMConfig internal nvmConfig;

  /// Only an account with the right role can access this function
  /// @param sender The address of the account calling this function
  /// @param role The role required to call this function
  error InvalidRole(address sender, bytes32 role);  

  event Received(
    address indexed _from, 
    uint256 _value
  );

  function initialize(address _nvmConfigAddress) public initializer {
    // AccessControlUpgradeable.__AccessControl_init();
    // AccessControlUpgradeable._grantRole(DEFAULT_ADMIN_ROLE, _owner);    
    nvmConfig = INVMConfig(_nvmConfigAddress);
  }  

  receive() external payable {
    emit Received(msg.sender, msg.value);
  }

  function deposit(uint256 assets, address receiver) 
  public
  override(ERC4626Upgradeable, IVault)  
  returns (uint256) {
    if (!nvmConfig.hasRole(msg.sender, DEPOSITOR_ROLE))
      revert InvalidRole(msg.sender, DEPOSITOR_ROLE);
    return super.deposit(assets, receiver);
  }

  // solhint-disable-next-line
  function mint(
    uint256 /*_shares*/, 
    address /*_receiver*/
  ) 
  public 
  override(ERC4626Upgradeable, IVault)   
  returns (uint256) {
    return 0;    
  }

  function withdraw(uint256 assets, address receiver, address owner) 
  public 
  override(ERC4626Upgradeable, IVault)
  returns (uint256) {
    if (!nvmConfig.hasRole(msg.sender, WITHDRAW_ROLE))
      revert InvalidRole(msg.sender, WITHDRAW_ROLE);
    return super.withdraw(assets, receiver, owner);
  }



}