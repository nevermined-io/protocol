// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

interface IVault {
  function depositNativeToken() external payable;
  function depositERC20(
    address _erc20TokenAddress,
    uint256 _amount,
    address _from
  ) external;
  function withdrawERC20(
    address _erc20TokenAddress,
    uint256 _amount,
    address _receiver
  ) external;
  function withdrawNativeToken(uint256 _amount, address _receiver) external;
  function getBalanceNativeToken() external view returns (uint256 balance);
  function getBalanceERC20(
    address _erc20TokenAddress
  ) external view returns (uint256 balance);
}
