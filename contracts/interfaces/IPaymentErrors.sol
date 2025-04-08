// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {IAsset} from './IAsset.sol';

/**
 * @title IPaymentErrors
 * @notice Error definitions for Payment-related contracts
 */
interface IPaymentErrors {
    /// Error sending native token (i.e ETH)
    error FailedToSendNativeToken();

    /// The msg.value (`msgValue`) doesn't match the amount (`amount`)
    /// @param msgValue The value sent in the transaction
    /// @param amount The amount to be transferred
    error InvalidTransactionAmount(uint256 msgValue, uint256 amount);

    /// The `priceType` given is not supported by the condition
    /// @param priceType The price type supported by the condition
    error UnsupportedPriceTypeOption(IAsset.PriceType priceType);

    /// The `amounts` and `receivers` are incorrect
    /// @param amounts The distribution of the payment amounts
    /// @param receivers The distribution of the payment amounts receivers
    error IncorrectPaymentDistribution(uint256[] amounts, address[] receivers);

    /**
     * Event emitted when native token is received
     * @param from address sending the native token
     * @param value amount of native token
     */
    event ReceivedNativeToken(
        address indexed from, 
        uint256 value
    );

    /**
     * Event emitted when native token is withdrawn
     * @param from address sending the withdraw request
     * @param receiver address receiving the native token
     * @param amount amount of native token withdrawn
     */
    event WithdrawNativeToken(    
        address indexed from, 
        address indexed receiver,
        uint256 amount
    );

    /**
     * Event emitted when ERC20 token is received
     * @param erc20TokenAddress address of the ERC20 token
     * @param from address sending the token
     * @param amount amount of ERC20 token
     */
    event ReceivedERC20(
        address indexed erc20TokenAddress,
        address indexed from, 
        uint256 amount
    );

    /**
     * Event emitted when ERC20 token is withdrawn
     * @param erc20TokenAddress address of the ERC20 token
     * @param from address sending the withdraw request
     * @param receiver address receiving the ERC20 token
     * @param amount amount of ERC20 token withdrawn
     */
    event WithdrawERC20(
        address indexed erc20TokenAddress,
        address indexed from, 
        address indexed receiver,
        uint256 amount
    );
}
