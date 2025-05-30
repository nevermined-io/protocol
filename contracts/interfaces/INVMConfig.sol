// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.30;

/**
 * @title Nevermined Configuration Interface
 * @author Nevermined AG
 * @notice Interface defining the core configuration management functionality for the Nevermined Protocol
 * @dev This interface establishes the contract functions and events required for maintaining
 * protocol-wide configuration, managing roles, and controlling access to administrative features
 */
interface INVMConfig {
    /**
     * @notice Event that is emitted when a configuration parameter is changed
     * @param whoChanged The address of the governor changing the parameter
     * @param parameter The hash of the name of the parameter changed
     * @param value The new value of the parameter
     */
    event NeverminedConfigChange(address indexed whoChanged, bytes32 indexed parameter, bytes value);

    /**
     * @notice Error thrown when an invalid network fee is provided
     * @dev Fee must be between 0 and FEE_DENOMINATOR (1,000,000, representing 100%)
     * @param networkFee The invalid network fee that was provided
     */
    error InvalidNetworkFee(uint256 networkFee);

    /**
     * @notice Error thrown when an invalid fee receiver address is provided
     * @dev The fee receiver cannot be the zero address when fees are enabled
     * @param feeReceiver The invalid fee receiver address that was provided
     */
    error InvalidFeeReceiver(address feeReceiver);

    /**
     * @notice Error thrown when an invalid address is provided to a function
     * @param _address The invalid address that was provided
     */
    error InvalidAddress(address _address);

    /**
     * @notice Retrieves the current network fee percentage
     * @dev The returned value must be divided by FEE_DENOMINATOR to get the actual percentage
     * @return Current network fee in parts per 1,000,000 (e.g., 10000 = 1%)
     */
    function getNetworkFee() external view returns (uint256);

    /**
     * @notice Retrieves the address that receives protocol fees
     * @dev If this returns the zero address and fees are set, fees cannot be collected
     * @return The current fee receiver address
     */
    function getFeeReceiver() external view returns (address);

    /**
     * @notice Returns the denominator used for fee calculations
     * @dev This is a constant value used as the denominator when calculating fee percentages
     * @return The fee denominator constant (1,000,000 representing 100% with 4 decimal places)
     */
    function getFeeDenominator() external pure returns (uint256);
}
