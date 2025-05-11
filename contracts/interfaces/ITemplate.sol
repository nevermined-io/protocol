// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

/**
 * @title Agreement Template Interface
 * @author Nevermined AG
 * @notice Interface defining the core error handling for Agreement Templates in the Nevermined Protocol
 * @dev This interface establishes the error types thrown by Agreement Template contracts,
 * which are used to define structured agreements between parties in the ecosystem
 */
interface ITemplate {
    /**
     * @notice Error thrown when an invalid seed is provided for agreement ID generation
     * @dev Agreement IDs are deterministic and generated from a seed that must meet specific criteria
     * @param seed The invalid seed provided to generate the agreementId
     */
    error InvalidSeed(bytes32 seed);

    /**
     * @notice Error thrown when an invalid DID is provided in an agreement creation process
     * @dev The DID must correspond to a registered asset in the Nevermined ecosystem
     * @param did The invalid DID of the asset related to the agreement being created
     */
    error InvalidDID(bytes32 did);

    /**
     * @notice Error thrown when an invalid plan ID is provided in an agreement creation process
     * @dev The plan ID must correspond to a registered plan in the Nevermined ecosystem
     * @param planId The invalid plan ID being used in the agreement
     */
    error InvalidPlanId(uint256 planId);

    /**
     * @notice Error thrown when an invalid receiver address is provided in an agreement creation process
     * @dev The receiver address must be a valid address
     * @param receiver The invalid receiver address being used in the agreement
     */
    error InvalidReceiver(address receiver);
}
