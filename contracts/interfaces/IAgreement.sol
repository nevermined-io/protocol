// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

interface IAgreement {
  /**
   * @notice Event that is emitted when a new Agreement is stored
   * @param agreementId the unique identifier of the agreement
   * @param creator the address of the account storing the agreement
   */
  event AgreementRegistered(bytes32 indexed agreementId, address indexed creator);

  /**
   * @notice Event that is emitted when a condition status is updated
   * @param agreementId the unique identifier of the agreement
   * @param conditionId the unique identifier of the condition
   * @param state the new state of the condition
   */
  event ConditionUpdated(
    bytes32 indexed agreementId,
    bytes32 indexed conditionId,
    ConditionState state
  );

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

  enum ConditionState {
    Uninitialized,
    Unfulfilled,
    Fulfilled,
    Aborted
  }

  struct Agreement {
    bytes32 did;
    uint256 planId;
    address agreementCreator;
    bytes32[] conditionIds;
    ConditionState[] conditionStates;
    // uint256[] timeLocks;
    // uint256[] timeOuts;
    bytes[] params;
    // When was the Agreement last updated
    uint256 lastUpdated;
  }

  function getAgreement(bytes32 _agreementId) external view returns (Agreement memory);

  function getConditionState(
    bytes32 _agreementId,
    bytes32 _conditionId
  ) external view returns (ConditionState state);

  function updateConditionStatus(
    bytes32 _agreementId,
    bytes32 _conditionId,
    ConditionState _state
  ) external;

  function agreementExists(bytes32 _agreementId) external view returns (bool);

  function areConditionsFulfilled(
    bytes32 _agreementId,
    bytes32 _conditionId,
    bytes32[] memory _dependantConditions
  ) external view returns (bool);
}
