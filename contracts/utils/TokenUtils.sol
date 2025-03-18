// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

library TokenUtils {
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
  ) public {
    if (_amount > 0) {
      IERC20 token = IERC20(_tokenAddress);
      token.approve(_receiverAddress, _amount);
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
  ) public {
    if (_amount > 0) {
      if (msg.value != _amount)
        revert InvalidTransactionAmount(msg.value, _amount);
      // solhint-disable-next-line
      (bool sent, ) = _receiverAddress.call{value: _amount}('');
      if (!sent) revert FailedToSendNativeToken();
    }
  }

  function calculateAmountSum(
    uint256[] memory _amounts
  ) public pure returns (uint256) {
    uint256 _totalAmount;
    for (uint256 i; i < _amounts.length; i++) _totalAmount += _amounts[i];
    return _totalAmount;
  }

  function onePercentCeil(uint256 _amount) public pure returns (uint256) {
    return calculateCeilPercent(_amount, 1, 1000000);
    //return (_amount * 1 + 99) / 100; // Equivalent to ceil(amount * 1 / 100)
  }

  function calculateCeilPercent(
    uint256 _amount,
    uint256 _percent,
    uint256 _denominator
  ) public pure returns (uint256) {
    return (_amount * _percent + (_denominator - _percent)) / _denominator; // Equivalent to ceil(amount * _percent / 100)
  }

  /**
   * Given the amounts and receivers, it adds the fee to the payment distribution.
   * Normally the `_feeAmount` and `_feeReceiver` parameters are coming from the fees existing on the NVMConfig contract.
   * @param _amounts The amounts to be distributed
   * @param _receivers The receivers of the amounts
   * @param _feeAmount The fee amount to be added to the distribution
   * @param _feeReceiver The receiver of the fee
   * @return amountsWithFee The amounts with the fee included
   * @return receiversWithFee The receivers with the fee included
   */
  function addFeeToPaymentDistribution(
    uint256[] calldata _amounts,
    address[] calldata _receivers,
    uint256 _feeAmount,
    address _feeReceiver
  ) public pure returns (uint256[] memory, address[] memory) {
    if (_feeAmount == 0 || _feeReceiver == address(0))
      return (_amounts, _receivers);

    uint256 _totalAmount = calculateAmountSum(_amounts);
    if (_totalAmount == 0) return (_amounts, _receivers);
    uint256 feeAmount = onePercentCeil(_totalAmount);
    if (feeAmount < 1) feeAmount = 1;

    uint256 length = _amounts.length;
    uint256[] memory amountsWithFee = new uint256[](length + 1);
    address[] memory receiversWithFee = new address[](length + 1);

    for (uint256 i = 0; i < length; i++) {
      amountsWithFee[i] = _amounts[i];
      receiversWithFee[i] = _receivers[i];
    }
    amountsWithFee[length] = feeAmount;
    receiversWithFee[length] = _feeReceiver;
    return (amountsWithFee, receiversWithFee);
  }
}
