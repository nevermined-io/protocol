// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

interface IVault {
  /**
   * Event triggered when a native token is received in the vault contract
   * @param from sender of the native token
   * @param value amount of native token received
   */
  event ReceivedNativeToken(address indexed from, uint256 value);

  /**
   * Event triggered when a native token is withdrawn from the vault contract
   * @param from account requesting the withdraw of the native token
   * @param receiver receiver of the native token
   * @param amount amount of native token withdrawn
   */
  event WithdrawNativeToken(address indexed from, address indexed receiver, uint256 amount);

  /**
   * Event triggered when an ERC20 token is received in the vault contract
   * @param erc20TokenAddress address of the ERC20 token
   * @param from sender of the ERC20 token
   * @param amount amount of ERC20 token received
   */
  event ReceivedERC20(address indexed erc20TokenAddress, address indexed from, uint256 amount);

  /**
   * Event triggered when an ERC20 token is withdrawn from the vault contract
   * @param erc20TokenAddress address of the ERC20 token
   * @param from account requesting the withdraw of the ERC20 token
   * @param receiver receiver of the ERC20 token
   * @param amount amount of ERC20 token withdrawn
   */
  event WithdrawERC20(
    address indexed erc20TokenAddress,
    address indexed from,
    address indexed receiver,
    uint256 amount
  );

  /// Only an account with the right role can access this function
  /// @param sender The address of the account calling this function
  /// @param role The role required to call this function
  error InvalidRole(address sender, bytes32 role);

  /// Error sending native token (i.e ETH)
  error FailedToSendNativeToken();

  function depositNativeToken() external payable;
  function depositERC20(address _erc20TokenAddress, uint256 _amount, address _from) external;
  function withdrawERC20(address _erc20TokenAddress, uint256 _amount, address _receiver) external;
  function withdrawNativeToken(uint256 _amount, address _receiver) external;
  function getBalanceNativeToken() external view returns (uint256 balance);
  function getBalanceERC20(address _erc20TokenAddress) external view returns (uint256 balance);
}
