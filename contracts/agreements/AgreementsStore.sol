// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {IAgreement} from '../interfaces/IAgreement.sol';
import {INVMConfig} from '../interfaces/INVMConfig.sol';

contract AgreementsStore is Initializable, IAgreement {
  bytes32 public constant NVM_CONTRACT_NAME = keccak256('AgreementsStore');

  INVMConfig internal nvmConfig;

  /// The mapping of the agreements registered in the contract
  mapping(bytes32 => IAgreement.Agreement) public agreements;

  /**
   * @notice Event that is emitted when a new Agreement is stored
   * @param agreementId the unique identifier of the agreement
   * @param creator the address of the account storing the agreement
   */
  event AgreementRegistered(
    bytes32 indexed agreementId,
    address indexed creator
  );

  function initialize(address _nvmConfigAddress) public initializer {
    nvmConfig = INVMConfig(_nvmConfigAddress);
  }

  function register(
    bytes32 _agreementId,
    address _agreementCreator,
    bytes32 _did,
    bytes32 _planId,
    bytes32[] memory _conditionIds,
    ConditionState[] memory _conditionStates,
    bytes[] memory _params
  ) public {
    if (!nvmConfig.isTemplate(msg.sender))
      revert INVMConfig.OnlyTemplate(msg.sender);

    if (agreements[_agreementId].lastUpdated != 0) {
      revert AgreementAlreadyRegistered(_agreementId);
    }
    agreements[_agreementId] = IAgreement.Agreement({
      did: _did,
      planId: _planId,
      agreementCreator: _agreementCreator,
      conditionIds: _conditionIds,
      conditionStates: _conditionStates,
      params: _params,
      lastUpdated: block.timestamp
    });
    emit AgreementRegistered(_agreementId, _agreementCreator);
  }

  function updateConditionStatus(
    bytes32 _agreementId,
    bytes32 _conditionId,
    ConditionState _state
  ) external {
    if (!nvmConfig.isTemplate(msg.sender) && !nvmConfig.isCondition(msg.sender))
      revert INVMConfig.OnlyTemplateOrCondition(msg.sender);

    IAgreement.Agreement storage agreement = agreements[_agreementId];
    if (agreement.lastUpdated == 0) {
      revert AgreementNotFound(_agreementId);
    }

    for (uint256 i = 0; i < agreement.conditionIds.length; i++) {
      if (agreement.conditionIds[i] == _conditionId) {
        agreement.conditionStates[i] = _state;
        return;
      }
    }
    revert IAgreement.ConditionIdNotFound(_conditionId);
  }

  function getAgreement(
    bytes32 _agreementId
  ) external view returns (Agreement memory) {
    return agreements[_agreementId];
  }

  function agreementExists(bytes32 _agreementId) external view returns (bool) {
    return agreements[_agreementId].lastUpdated != 0;
  }

  function areConditionsFulfilled(
    bytes32 _agreementId,
    bytes32 _conditionId,
    bytes32[] memory _dependantConditions
  ) external view returns (bool) {
    IAgreement.Agreement memory agreement = agreements[_agreementId];
    if (agreement.lastUpdated == 0) {
      revert AgreementNotFound(_agreementId);
    }

    uint256 numChecksPassed = 0;
    for (uint256 i = 0; i < agreement.conditionStates.length; i++) {
      if (agreement.conditionIds[i] == _conditionId) {
        if (
          agreement.conditionStates[i] == ConditionState.Fulfilled ||
          agreement.conditionStates[i] == ConditionState.Aborted
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
   * @notice It generates a agreementId using as seed a bytes32 and the address of the Agreement creator
   * @param _seed refers to the agreementId seed used as base to generate the final agreementId
   * @param _creator address of the creator of the Agreement
   * @return the new agreementId created
   */
  function hashAgreementId(
    bytes32 _seed,
    address _creator
  ) public pure returns (bytes32) {
    return keccak256(abi.encode(_seed, _creator));
  }
}
