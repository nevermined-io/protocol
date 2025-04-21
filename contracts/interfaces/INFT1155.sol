// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {IAsset} from '../interfaces/IAsset.sol';

bytes32 constant CREDITS_BURN_PROOF_TYPEHASH =
    keccak256(abi.encodePacked('CreditsBurnProofData(uint256 keyspace,uint256 nonce,uint256[] planIds)'));

interface INFT1155 {
    struct CreditsBurnProofData {
        uint256 keyspace;
        uint256 nonce;
        uint256[] planIds;
    }

    /// The redemption permissions of the plan with id `planId` are not valid for the account `sender`
    /// @param planId The identifier of the plan
    /// @param redemptionType The type of redemptions that can be used for the plan
    /// @param sender The address of the account calling this function
    error InvalidRedemptionPermission(uint256 planId, IAsset.RedemptionType redemptionType, address sender);

    /// The lentgh of the ids and values arrays must be the same
    /// @param idsLength The length of the ids array
    /// @param valuesLength The length of the values array
    error InvalidLength(uint256 idsLength, uint256 valuesLength);

    /// The signature is invalid
    /// @param signer The address of the account that signed the proof
    /// @param from The address of the account that is getting the credits burned
    error InvalidCreditsBurnProof(address signer, address from);

    /// Returns the next nonce for the given sender and keyspace
    /// @param _sender The address of the account
    /// @param _keyspace The keyspaces for which to generate the nonce
    /// @return The next nonce value
    function nextNonce(address _sender, uint256[] calldata _keyspace) external view returns (uint256[] memory);
}
