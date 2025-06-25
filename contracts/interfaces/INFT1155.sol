// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.30;

import {IAsset} from '../interfaces/IAsset.sol';

bytes32 constant CREDITS_BURN_PROOF_TYPEHASH =
    keccak256(abi.encodePacked('CreditsBurnProofData(uint256 keyspace,uint256 nonce,uint256[] planIds)'));

/**
 * @title NFT1155 Interface
 * @author Nevermined AG
 * @notice Interface defining the errors and functionality for NFT1155 tokens in the Nevermined ecosystem
 * @dev This interface establishes the error handling for ERC-1155 based NFTs that represent
 * subscription credits, access rights, or other tokenized assets in the protocol
 */
interface INFT1155 {
    /**
     * @title CreditsBurnProofData
     * @notice This struct is signed by the owner of the credits to authorize the redemption of credits
     * @notice Data structure for credits burn proofs
     * @dev Contains the keyspace, nonce, and plan IDs for a credits burn proof
     */
    struct CreditsBurnProofData {
        uint256 keyspace;
        uint256 nonce;
        uint256[] planIds;
    }

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

    /// The signature is invalid
    /// @param signer The address of the account that signed the proof
    /// @param from The address of the account that is getting the credits burned
    error InvalidCreditsBurnProof(address signer, address from);

    /// @param role The role that is invalid
    /// @param sender The address of the account that is getting the role
    error InvalidRole(address sender, uint64 role);

    /**
     * @notice Error thrown when an invalid authority address is provided in an agreement creation process
     * @dev The authority address must be a valid address
     */
    error InvalidAuthorityAddress();

    /**
     * @notice Error thrown when an invalid vault address is provided in an agreement creation process
     * @dev The vault address must be a valid address
     */
    error InvalidVaultAddress();

    /**
     * @notice Error thrown when an invalid assets registry address is provided in an agreement creation process
     * @dev The assets registry address must be a valid address
     */
    error InvalidAssetsRegistryAddress();

    /// Returns the next nonce for the given sender and keyspace
    /// @param _sender The address of the account
    /// @param _keyspace The keyspaces for which to generate the nonce
    /// @return The next nonce value
    function nextNonce(address _sender, uint256[] calldata _keyspace) external view returns (uint256[] memory);
}
