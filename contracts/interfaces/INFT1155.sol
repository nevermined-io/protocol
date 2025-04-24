// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {IAsset} from '../interfaces/IAsset.sol';

/**
 * @title NFT1155 Interface
 * @author Nevermined AG
 * @notice Interface defining the errors and functionality for NFT1155 tokens in the Nevermined ecosystem
 * @dev This interface establishes the error handling for ERC-1155 based NFTs that represent
 * subscription credits, access rights, or other tokenized assets in the protocol
 */
interface INFT1155 {
    /**
     * @notice Error thrown when attempting to redeem a plan with invalid permissions
     * @dev Each plan has specific redemption types that control who can redeem it
     * @param planId The identifier of the plan being redeemed
     * @param redemptionType The type of redemptions that can be used for the plan
     * @param sender The address of the account attempting the redemption
     */
    error InvalidRedemptionPermission(uint256 planId, IAsset.RedemptionType redemptionType, address sender);

    /**
     * @notice Error thrown when array lengths for token IDs and values don't match
     * @dev This typically happens in batch operations where each ID must have a corresponding value
     * @param idsLength The length of the ids array provided
     * @param valuesLength The length of the values array provided
     */
    error InvalidLength(uint256 idsLength, uint256 valuesLength);
}
