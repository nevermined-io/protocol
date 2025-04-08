// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

/**
 * @title IAssetErrors
 * @notice Error definitions for Asset-related contracts
 */
interface IAssetErrors {
    /// A plan with the same `plainId` is already registered and can not be registered again.abi
    /// The `planId` is computed using the hash of the `PriceConfig`, `CreditsConfig`, `nftAddress` and the creator of the plan
    /// @param planId The identifier of the plan
    error PlanAlreadyRegistered(bytes32 planId);

    /// The DID `did` representing the key for an Asset is already registered
    /// @param did The identifier of the asset to register
    error DIDAlreadyRegistered(bytes32 did);

    /// When registering the asset, the plans array is empty
    /// @param did The identifier to register
    error NotPlansAttached(bytes32 did);

    /// The `did` representing the unique identifier of an Asset doesn't exist
    /// @param did The decentralized identifier of the Asset
    error AssetNotFound(bytes32 did);

    /// The `planId` representing the unique identifier of Plan doesn't exist
    /// @param planId The unique identifier of a Plan
    error PlanNotFound(bytes32 planId);

    /// The `amounts` and `receivers` do not include the Nevermined fees
    /// @param amounts The distribution of the payment amounts
    /// @param receivers The distribution of the payment amounts receivers
    error NeverminedFeesNotIncluded(uint256[] amounts, address[] receivers);

    /**
     * @notice Event that is emitted when a new Asset is registered
     * @param did the unique identifier of the asset
     * @param creator the address of the account registering the asset
     */
    event AssetRegistered(bytes32 indexed did, address indexed creator);

    /**
     * @notice Event that is emitted when a new plan is registered
     * @param planId the unique identifier of the plan
     * @param creator the address of the account registering the plan
     */
    event PlanRegistered(bytes32 indexed planId, address indexed creator);
}
