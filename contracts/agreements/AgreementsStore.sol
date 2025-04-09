// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { IAgreement } from "../interfaces/IAgreement.sol";
import { INVMConfig } from "../interfaces/INVMConfig.sol";
import { AccessManagedUUPSUpgradeable } from "../proxy/AccessManagedUUPSUpgradeable.sol";

contract AgreementsStore is IAgreement, AccessManagedUUPSUpgradeable {
  bytes32 public constant NVM_CONTRACT_NAME = keccak256("AgreementsStore");

  // keccak256(abi.encode(uint256(keccak256("nevermined.agreementsstore.storage")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant AGREEMENTS_STORE_STORAGE_LOCATION =
    0x22178a4c33a657e121fdb7f7ff8e08c307799179d05b9d9f8e256841a6d9d000;

  /// @custom:storage-location erc7201:nevermined.agreementsstore.storage
  struct AgreementsStoreStorage {
    INVMConfig nvmConfig;
    /// The mapping of the agreements registered in the contract
    mapping(bytes32 => IAgreement.Agreement) agreements;
  }

  function initialize(address _nvmConfigAddress, address _authority) public initializer {
    _getAgreementsStoreStorage().nvmConfig = INVMConfig(_nvmConfigAddress);
    __AccessManagedUUPSUpgradeable_init(_authority);
  }

  function register(
    bytes32 _agreementId,
    address _agreementCreator,
    bytes32 _did,
    uint256 _planId,
    bytes32[] memory _conditionIds,
    ConditionState[] memory _conditionStates,
    bytes[] memory _params
  ) public {
    AgreementsStoreStorage storage $ = _getAgreementsStoreStorage();

    if (!$.nvmConfig.isTemplate(msg.sender)) revert INVMConfig.OnlyTemplate(msg.sender);

    if ($.agreements[_agreementId].lastUpdated != 0) {
      revert AgreementAlreadyRegistered(_agreementId);
    }
    $.agreements[_agreementId] = IAgreement.Agreement({
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

  function getAgreement(bytes32 _agreementId) external view returns (IAgreement.Agreement memory) {
    AgreementsStoreStorage storage $ = _getAgreementsStoreStorage();
    return $.agreements[_agreementId];
  }

  function getConditionState(
    bytes32 _agreementId,
    bytes32 _conditionId
  ) external view returns (ConditionState state) {
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

  function agreementExists(bytes32 _agreementId) external view returns (bool) {
    AgreementsStoreStorage storage $ = _getAgreementsStoreStorage();
    return $.agreements[_agreementId].lastUpdated != 0;
  }

  function areConditionsFulfilled(
    bytes32 _agreementId,
    bytes32 _conditionId,
    bytes32[] memory _dependantConditions
  ) external view returns (bool) {
    AgreementsStoreStorage storage $ = _getAgreementsStoreStorage();
    IAgreement.Agreement storage agreement = $.agreements[_agreementId];
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
  function hashAgreementId(bytes32 _seed, address _creator) public pure returns (bytes32) {
    return keccak256(abi.encode(_seed, _creator));
  }

  function _getAgreementsStoreStorage() internal pure returns (AgreementsStoreStorage storage $) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      $.slot := AGREEMENTS_STORE_STORAGE_LOCATION
    }
  }
}
