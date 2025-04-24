// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {IAgreement} from '../interfaces/IAgreement.sol';
import {INVMConfig} from '../interfaces/INVMConfig.sol';
import {AccessManagedUUPSUpgradeable} from '../proxy/AccessManagedUUPSUpgradeable.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';

/**
 * @title AgreementsStore
 * @author Nevermined
 * @notice Central registry for all agreements within the Nevermined protocol
 * @dev The AgreementsStore manages the lifecycle of agreements and their associated conditions
 *      acting as a source of truth for agreement states. It maintains an immutable record of
 *      all agreements and their conditions, allowing only authorized templates and conditions
 *      to register and update agreement states. The contract uses ERC-7201 namespaced storage
 *      pattern for upgrade safety and implements access controls to ensure only authorized
 *      contracts can modify agreement data.
 */
contract AgreementsStore is IAgreement, AccessManagedUUPSUpgradeable {
    bytes32 public constant NVM_CONTRACT_NAME = keccak256('AgreementsStore');

    // keccak256(abi.encode(uint256(keccak256("nevermined.agreementsstore.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AGREEMENTS_STORE_STORAGE_LOCATION =
        0x22178a4c33a657e121fdb7f7ff8e08c307799179d05b9d9f8e256841a6d9d000;

    /// @custom:storage-location erc7201:nevermined.agreementsstore.storage
    struct AgreementsStoreStorage {
        INVMConfig nvmConfig;
        /// The mapping of the agreements registered in the contract
        mapping(bytes32 => IAgreement.Agreement) agreements;
    }

    /**
     * @notice Initializes the AgreementsStore contract
     * @param _nvmConfigAddress Address of the NVMConfig contract managing system configuration
     * @param _authority Address of the AccessManager contract handling permissions
     * @dev Sets up the contract with the required configuration and access control settings
     */
    function initialize(INVMConfig _nvmConfigAddress, IAccessManager _authority) external initializer {
        _getAgreementsStoreStorage().nvmConfig = _nvmConfigAddress;
        __AccessManagedUUPSUpgradeable_init(address(_authority));
    }

    /**
     * @notice Registers a new agreement with its conditions
     * @param _agreementId Unique identifier for the agreement
     * @param _agreementCreator Address of the agreement creator
     * @param _planId Identifier of the pricing plan
     * @param _conditionIds Array of condition identifiers associated with the agreement
     * @param _conditionStates Initial states of the conditions
     * @param _params Additional parameters for the agreement
     * @dev Only templates can register agreements
     * @dev Emits AgreementRegistered event on successful registration
     * @dev Each agreement must have a unique ID and can only be registered once
     */
    function register(
        bytes32 _agreementId,
        address _agreementCreator,
        uint256 _planId,
        bytes32[] memory _conditionIds,
        ConditionState[] memory _conditionStates,
        bytes[] memory _params
    ) external {
        AgreementsStoreStorage storage $ = _getAgreementsStoreStorage();

        if (!$.nvmConfig.isTemplate(msg.sender)) revert INVMConfig.OnlyTemplate(msg.sender);

        if ($.agreements[_agreementId].lastUpdated != 0) {
            revert AgreementAlreadyRegistered(_agreementId);
        }
        $.agreements[_agreementId] = IAgreement.Agreement({
            planId: _planId,
            agreementCreator: _agreementCreator,
            conditionIds: _conditionIds,
            conditionStates: _conditionStates,
            params: _params,
            lastUpdated: block.timestamp
        });
        emit AgreementRegistered(_agreementId, _agreementCreator);
    }

    /**
     * @notice Updates the status of a condition within an agreement
     * @param _agreementId Identifier of the agreement
     * @param _conditionId Identifier of the condition to update
     * @param _state New state for the condition
     * @dev Only templates or conditions can update condition states
     * @dev Emits ConditionUpdated event on successful update
     * @dev The agreement must exist and contain the specified condition
     */
    function updateConditionStatus(bytes32 _agreementId, bytes32 _conditionId, ConditionState _state) external {
        AgreementsStoreStorage storage $ = _getAgreementsStoreStorage();

        if (!$.nvmConfig.isTemplate(msg.sender) && !$.nvmConfig.isCondition(msg.sender)) {
            revert INVMConfig.OnlyTemplateOrCondition(msg.sender);
        }

        IAgreement.Agreement storage agreement = $.agreements[_agreementId];
        if (agreement.lastUpdated == 0) {
            revert AgreementNotFound(_agreementId);
        }

        for (uint256 i = 0; i < agreement.conditionIds.length; i++) {
            if (agreement.conditionIds[i] == _conditionId) {
                agreement.conditionStates[i] = _state;
                emit ConditionUpdated(_agreementId, _conditionId, _state);
                return;
            }
        }
        revert IAgreement.ConditionIdNotFound(_conditionId);
    }

    /**
     * @notice Retrieves an agreement by its identifier
     * @param _agreementId The unique identifier of the agreement to retrieve
     * @return The Agreement structure containing the agreement's details
     * @dev Returns the complete agreement data including conditions, states, and parameters
     */
    function getAgreement(bytes32 _agreementId) external view returns (IAgreement.Agreement memory) {
        AgreementsStoreStorage storage $ = _getAgreementsStoreStorage();
        return $.agreements[_agreementId];
    }

    /**
     * @notice Gets the current state of a specific condition within an agreement
     * @param _agreementId Identifier of the agreement
     * @param _conditionId Identifier of the condition
     * @return state The current state of the condition
     * @dev Reverts if the agreement or condition doesn't exist
     * @dev Iterates through the agreement's conditions to find the matching condition ID
     */
    function getConditionState(bytes32 _agreementId, bytes32 _conditionId)
        external
        view
        returns (ConditionState state)
    {
        AgreementsStoreStorage storage $ = _getAgreementsStoreStorage();
        IAgreement.Agreement storage agreement = $.agreements[_agreementId];
        if (agreement.lastUpdated == 0) {
            revert AgreementNotFound(_agreementId);
        }
        for (uint256 i = 0; i < agreement.conditionStates.length; i++) {
            if (agreement.conditionIds[i] == _conditionId) return agreement.conditionStates[i];
        }
        revert ConditionIdNotFound(_conditionId);
    }

    /**
     * @notice Checks if an agreement exists by its identifier
     * @param _agreementId The unique identifier of the agreement to check
     * @return Boolean indicating whether the agreement exists
     * @dev An agreement exists if its lastUpdated timestamp is non-zero
     */
    function agreementExists(bytes32 _agreementId) external view returns (bool) {
        AgreementsStoreStorage storage $ = _getAgreementsStoreStorage();
        return $.agreements[_agreementId].lastUpdated != 0;
    }

    /**
     * @notice Checks if all required conditions are fulfilled for a specific condition
     * @param _agreementId Identifier of the agreement
     * @param _conditionId Identifier of the condition to check
     * @param _dependantConditions Array of dependent condition identifiers that must be fulfilled
     * @return Boolean indicating whether all required conditions are fulfilled
     * @dev Returns false if the target condition is already fulfilled or aborted
     * @dev Returns false if any dependent condition is not fulfilled
     * @dev Used to enforce condition dependencies in agreement execution flow
     */
    function areConditionsFulfilled(bytes32 _agreementId, bytes32 _conditionId, bytes32[] memory _dependantConditions)
        external
        view
        returns (bool)
    {
        AgreementsStoreStorage storage $ = _getAgreementsStoreStorage();
        IAgreement.Agreement storage agreement = $.agreements[_agreementId];
        if (agreement.lastUpdated == 0) {
            revert AgreementNotFound(_agreementId);
        }

        uint256 numChecksPassed = 0;
        for (uint256 i = 0; i < agreement.conditionStates.length; i++) {
            if (agreement.conditionIds[i] == _conditionId) {
                if (
                    agreement.conditionStates[i] == ConditionState.Fulfilled
                        || agreement.conditionStates[i] == ConditionState.Aborted
                ) {
                    // The condition is already fulfilled or aborted
                    return false;
                }
                numChecksPassed++;
            } else {
                for (uint256 j = 0; j < _dependantConditions.length; j++) {
                    if (agreement.conditionIds[i] == _dependantConditions[j]) {
                        // Found a dependant condition
                        if (agreement.conditionStates[i] != ConditionState.Fulfilled) {
                            // The dependant condition is not fulfilled
                            return false;
                        }
                        numChecksPassed++;
                    }
                }
            }
        }
        return numChecksPassed == _dependantConditions.length + 1;
    }

    /**
     * @notice Generates a unique agreement ID from a seed and creator address
     * @param _seed Seed for agreement ID generation
     * @param _creator Address of the agreement creator
     * @return The generated agreement ID
     * @dev Uses keccak256 hashing to ensure uniqueness of agreement IDs
     */
    function hashAgreementId(bytes32 _seed, address _creator) external pure returns (bytes32) {
        return keccak256(abi.encode(_seed, _creator));
    }

    /**
     * @notice Internal function to get the contract's storage reference
     * @return $ Storage reference to the AgreementsStoreStorage struct
     * @dev Uses ERC-7201 namespaced storage pattern for upgrade safety
     */
    function _getAgreementsStoreStorage() internal pure returns (AgreementsStoreStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            $.slot := AGREEMENTS_STORE_STORAGE_LOCATION
        }
    }
}
