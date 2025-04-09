// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { INVMConfig } from './interfaces/INVMConfig.sol';
import { IVault } from './interfaces/IVault.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { ReentrancyGuardUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import { AccessManagedUUPSUpgradeable } from './proxy/AccessManagedUUPSUpgradeable.sol';

contract PaymentsVault is IVault, ReentrancyGuardUpgradeable, AccessManagedUUPSUpgradeable {
  /**
   * @notice Role allowing to deposit assets into the Vault
   */
  bytes32 public constant DEPOSITOR_ROLE = keccak256('VAULT_DEPOSITOR_ROLE');

  /**
   * @notice Role allowing to withdraw assets from the Vault
   */
  bytes32 public constant WITHDRAW_ROLE = keccak256('VAULT_WITHDRAW_ROLE');

  // keccak256(abi.encode(uint256(keccak256("nevermined.paymentsvault.storage")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant PAYMENTS_VAULT_STORAGE_LOCATION =
    0x80a73158257d9dc2a97871b2d2c51b86390aa280667a4b04612145b2777aba00;

  /// @custom:storage-location erc7201:nevermined.paymentsvault.storage
  struct PaymentsVaultStorage {
    INVMConfig nvmConfig;
  }

  function initialize(address _nvmConfigAddress, address _authority) public initializer {
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    PaymentsVaultStorage storage $ = _getPaymentsVaultStorage();
    $.nvmConfig = INVMConfig(_nvmConfigAddress);
    __AccessManagedUUPSUpgradeable_init(_authority);
  }

  receive() external payable {
    if (!_getPaymentsVaultStorage().nvmConfig.hasRole(msg.sender, DEPOSITOR_ROLE)) {
      revert InvalidRole(msg.sender, DEPOSITOR_ROLE);
    }
    emit ReceivedNativeToken(msg.sender, msg.value);
  }

  function depositNativeToken() external payable nonReentrant {
    if (!_getPaymentsVaultStorage().nvmConfig.hasRole(msg.sender, DEPOSITOR_ROLE)) {
      revert InvalidRole(msg.sender, DEPOSITOR_ROLE);
    }
    emit ReceivedNativeToken(msg.sender, msg.value);
  }

  function withdrawNativeToken(uint256 _amount, address _receiver) external nonReentrant {
    if (!_getPaymentsVaultStorage().nvmConfig.hasRole(msg.sender, WITHDRAW_ROLE)) {
      revert InvalidRole(msg.sender, WITHDRAW_ROLE);
    }

    // Emit event before external call to follow checks-effects-interactions pattern
    emit WithdrawNativeToken(msg.sender, _receiver, _amount);

    // Skip transfer if amount is 0
    if (_amount > 0) {
      (bool sent, ) = _receiver.call{ value: _amount }('');
      if (!sent) revert FailedToSendNativeToken();
    }
  }

  function depositERC20(
    address _erc20TokenAddress,
    uint256 _amount,
    address _from
  ) external nonReentrant {
    if (!_getPaymentsVaultStorage().nvmConfig.hasRole(msg.sender, DEPOSITOR_ROLE)) {
      revert InvalidRole(msg.sender, DEPOSITOR_ROLE);
    }
    emit ReceivedERC20(_erc20TokenAddress, _from, _amount);
  }

  function withdrawERC20(
    address _erc20TokenAddress,
    uint256 _amount,
    address _receiver
  ) external nonReentrant {
    if (!_getPaymentsVaultStorage().nvmConfig.hasRole(msg.sender, WITHDRAW_ROLE)) {
      revert InvalidRole(msg.sender, WITHDRAW_ROLE);
    }

    // Emit event before external call to follow checks-effects-interactions pattern
    emit WithdrawERC20(_erc20TokenAddress, msg.sender, _receiver, _amount);

    // Skip transfer if amount is 0
    if (_amount > 0) {
      IERC20 token = IERC20(_erc20TokenAddress);
      // Use transfer instead of transferFrom since we're sending from our own balance
      token.transfer(_receiver, _amount);
    }
  }

  function getBalanceNativeToken() external view returns (uint256 balance) {
    return address(this).balance;
  }

  function getBalanceERC20(address _erc20TokenAddress) external view returns (uint256 balance) {
    IERC20 token = IERC20(_erc20TokenAddress);
    return token.balanceOf(address(this));
  }

  function _getPaymentsVaultStorage() internal pure returns (PaymentsVaultStorage storage $) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      $.slot := PAYMENTS_VAULT_STORAGE_LOCATION
    }
  }
}
