// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

abstract contract TokenUtils {
  /// Error sending native token (i.e ETH)
  error FailedToSendNativeToken();

  /// The msg.value (`msgValue`) doesn't match the amount (`amount`)
  /// @param msgValue The value sent in the transaction
  /// @param amount The amount to be transferred
  error InvalidTransactionAmount(uint256 msgValue, uint256 amount);

  /**
   * @notice _transferERC20 transfer ERC20 tokens
   * @param _senderAddress the address to send the tokens from
   * @param _receiverAddress the address to receive the tokens
   * @param _tokenAddress the ERC20 contract address to use during the payment
   * @param _amount token amount to be locked/released
   * @dev Will throw if transfer fails
   */
  function transferERC20(
    address _senderAddress,
    address _receiverAddress,
    address _tokenAddress,
    uint256 _amount
  ) internal {
    if (_amount > 0) {
      IERC20 token = IERC20(_tokenAddress);
      token.transferFrom(_senderAddress, _receiverAddress, _amount);
    }
  }

  /**
   * @notice _transferNativeToken transfers tje Native token of the network (ETH, ..) to a `_receiverAddress`
   * @param _receiverAddress the address to receive the ETH
   * @param _amount Native token (ETH, ...) amount to be transferred
   */
  function transferNativeToken(
    address payable _receiverAddress,
    uint256 _amount
  ) internal {
    if (_amount > 0) {
      if (msg.value != _amount)
        revert InvalidTransactionAmount(msg.value, _amount);
      // solhint-disable-next-line
      (bool sent, ) = _receiverAddress.call{value: _amount}('');
      if (!sent) revert FailedToSendNativeToken();
    }
  }
}
