// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {INVMConfig} from './interfaces/INVMConfig.sol';
import {IVault} from './interfaces/IVault.sol';
import {IPaymentErrors} from './interfaces/IPaymentErrors.sol';
import {ITokenErrors} from './interfaces/ITokenErrors.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';


contract PaymentsVault is Initializable, IVault, ReentrancyGuardUpgradeable {

  /**
   * @notice Role allowing to deposit assets into the Vault
  */
  bytes32 public constant DEPOSITOR_ROLE = keccak256('VAULT_DEPOSITOR_ROLE');

  /**
   * @notice Role allowing to withdraw assets from the Vault
  */
  bytes32 public constant WITHDRAW_ROLE = keccak256('VAULT_WITHDRAW_ROLE');

  INVMConfig internal nvmConfig;

  // Error and event definitions moved to ICommon

  function initialize(address _nvmConfigAddress) public initializer {
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();    
    nvmConfig = INVMConfig(_nvmConfigAddress);
  }  

  receive() external payable {
    if (!nvmConfig.hasRole(msg.sender, DEPOSITOR_ROLE))
      revert ITokenErrors.InvalidRole(msg.sender, DEPOSITOR_ROLE);
    emit IPaymentErrors.ReceivedNativeToken(msg.sender, msg.value);
  }

  function depositNativeToken() 
  external payable nonReentrant
  {
    if (!nvmConfig.hasRole(msg.sender, DEPOSITOR_ROLE))
      revert ITokenErrors.InvalidRole(msg.sender, DEPOSITOR_ROLE);
    emit IPaymentErrors.ReceivedNativeToken(msg.sender, msg.value);
  }

  function withdrawNativeToken(uint256 _amount, address _receiver) 
  external nonReentrant  
  {
    if (!nvmConfig.hasRole(msg.sender, WITHDRAW_ROLE)) revert ITokenErrors.InvalidRole(msg.sender, WITHDRAW_ROLE);
    
    (bool sent, ) = _receiver.call{value: _amount}('');
    if (!sent) revert IPaymentErrors.FailedToSendNativeToken();

    emit IPaymentErrors.WithdrawNativeToken(msg.sender, _receiver, _amount);    
  }

  function depositERC20(address _erc20TokenAddress, uint256 _amount, address _from) 
  external nonReentrant 
  {
    if (!nvmConfig.hasRole(msg.sender, DEPOSITOR_ROLE))
      revert ITokenErrors.InvalidRole(msg.sender, DEPOSITOR_ROLE);
    emit IPaymentErrors.ReceivedERC20(_erc20TokenAddress, _from, _amount);    
  }

  function withdrawERC20(address _erc20TokenAddress, uint256 _amount, address _receiver) 
  external nonReentrant  
  {
    if (!nvmConfig.hasRole(msg.sender, WITHDRAW_ROLE))
      revert ITokenErrors.InvalidRole(msg.sender, WITHDRAW_ROLE);
    
    IERC20 token = IERC20(_erc20TokenAddress);
    token.approve(_receiver, _amount);
    token.transferFrom(address(this), _receiver, _amount);
    
    emit IPaymentErrors.WithdrawERC20(_erc20TokenAddress, msg.sender, _receiver, _amount);    
  }

  function getBalanceNativeToken() external view returns (uint256 balance) {
    return address(this).balance;
  }

  function getBalanceERC20(address _erc20TokenAddress) external view returns (uint256 balance) {
    IERC20 token = IERC20(_erc20TokenAddress);
    return token.balanceOf(address(this));    
  }

}
