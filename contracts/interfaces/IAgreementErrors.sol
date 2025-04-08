// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

/**
 * @title IAgreementErrors
 * @notice Error definitions for Agreement-related contracts
 */
interface IAgreementErrors {
    /// The `agreementId` representing the key for an Agreement is already registered
    /// @param agreementId The identifier of the agreement to store
    error AgreementAlreadyRegistered(bytes32 agreementId);

    /// The `agreementId` representing the key for an Agreement doesn't exist
    /// @param agreementId The identifier of the agreement to store
    error AgreementNotFound(bytes32 agreementId);

    /// The `conditionId` doesn't exist as part of the agreement
    /// @param conditionId The identifier of the condition associated to the agreement
    error ConditionIdNotFound(bytes32 conditionId);

    /// The preconditions for the the agreement `agreementId` are not met
    /// @param agreementId The identifier of the agreement to store
    /// @param conditionId The identifier of the condition associated to the agreement
    error ConditionPreconditionFailed(bytes32 agreementId, bytes32 conditionId);

    /**
     * @notice Event that is emitted when a new Agreement is stored
     * @param agreementId the unique identifier of the agreement
     * @param creator the address of the account storing the agreement
     */
    event AgreementRegistered(
        bytes32 indexed agreementId,
        address indexed creator
    );
}
