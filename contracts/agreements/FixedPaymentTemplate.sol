// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {INVMConfig} from '../interfaces/INVMConfig.sol';
import {AgreementsStore} from './AgreementsStore.sol';
import {BaseTemplate} from './BaseTemplate.sol';
import {IAgreement} from '../interfaces/IAgreement.sol';
import {LockPaymentCondition} from '../conditions/LockPaymentCondition.sol';
import {TransferCreditsCondition} from '../conditions/TransferCreditsCondition.sol';
import {DistributePaymentsCondition} from '../conditions/DistributePaymentsCondition.sol';

contract FixedPaymentTemplate is BaseTemplate {
  bytes32 public constant NVM_CONTRACT_NAME = keccak256('FixedPaymentTemplate');

  INVMConfig internal nvmConfig;
  // Conditions required to execute this template
  LockPaymentCondition internal lockPaymentCondition;
  TransferCreditsCondition internal transferCondition;
  DistributePaymentsCondition internal distributePaymentsCondition;

  function initialize(
    address _nvmConfigAddress,
    address _agreementStoreAddress,
    address _lockPaymentConditionAddress,
    address _transferCondtionAddress,
    address _distributePaymentsCondition
  ) public initializer {
    nvmConfig = INVMConfig(_nvmConfigAddress);
    agreementStore = AgreementsStore(_agreementStoreAddress);
    lockPaymentCondition = LockPaymentCondition(_lockPaymentConditionAddress);
    transferCondition = TransferCreditsCondition(_transferCondtionAddress);
    distributePaymentsCondition = DistributePaymentsCondition(
      _distributePaymentsCondition
    );
  }

  function createAgreement(
    bytes32 _seed,
    bytes32 _did,
    bytes32 _planId,
    bytes[] memory _params
  ) external payable {
    // STEPS:
    // 0. Calculate agreementId
    bytes32 agreementId = keccak256(
      abi.encode(NVM_CONTRACT_NAME, msg.sender, _seed, _did, _planId, _params)
    );

    // 1. Check if the agreement is already registered
    IAgreement.Agreement memory agreement = agreementStore.getAgreement(
      agreementId
    );

    if (agreement.lastUpdated != 0) {
      revert IAgreement.AgreementAlreadyRegistered(agreementId);
    }

    // LockPaymentCondition.NVM_CONTRACT_NAME
    // 2. Register the agreement in the AgreementsStore
    bytes32[] memory conditionIds = new bytes32[](3);
    conditionIds[0] = lockPaymentCondition.hashConditionId(
      agreementId,
      lockPaymentCondition.NVM_CONTRACT_NAME()
    );
    conditionIds[1] = transferCondition.hashConditionId(
      agreementId,
      transferCondition.NVM_CONTRACT_NAME()
    );
    conditionIds[2] = distributePaymentsCondition.hashConditionId(
      agreementId,
      distributePaymentsCondition.NVM_CONTRACT_NAME()
    );

    // IAgreement.ConditionState[] memory _conditionStates = new IAgreement.ConditionState[](3);

    agreementStore.register(
      agreementId,
      msg.sender,
      _did,
      _planId,
      conditionIds,
      new IAgreement.ConditionState[](3),
      _params
    );

    // 3. Lock the payment
    _lockPayment(conditionIds[0], agreementId, _did, _planId, msg.sender);
    _transferPlan(
      conditionIds[1],
      agreementId,
      _did,
      _planId,
      conditionIds[0],
      msg.sender
    );
    _distributePayments(
      conditionIds[2],
      agreementId,
      _did,
      _planId,
      conditionIds[0],
      conditionIds[1]
    );
  }

  function _lockPayment(
    bytes32 _conditionId,
    bytes32 _agreementId,
    bytes32 _did,
    bytes32 _planId,
    address _senderAddress
  ) internal {
    lockPaymentCondition.fulfill{value: msg.value}(
      _conditionId,
      _agreementId,
      _did,
      _planId,
      _senderAddress
    );
  }

  function _transferPlan(
    bytes32 _conditionId,
    bytes32 _agreementId,
    bytes32 _did,
    bytes32 _planId,
    bytes32 _lockPaymentCondition,
    address _receiverAddress
  ) internal {
    bytes32[] memory _requiredConditons = new bytes32[](1);
    _requiredConditons[0] = _lockPaymentCondition;
    transferCondition.fulfill(
      _conditionId,
      _agreementId,
      _did,
      _planId,
      _requiredConditons,
      _receiverAddress
    );
  }

  function _distributePayments(
    bytes32 _conditionId,
    bytes32 _agreementId,
    bytes32 _did,
    bytes32 _planId,
    bytes32 _lockPaymentCondition,
    bytes32 _releaseCondition
  ) public {
    // bytes32[] memory _requiredConditons = new bytes32[](2);
    // _requiredConditons[0] = _lockPaymentCondition;
    // _requiredConditons[1] = _transferCondition;

    distributePaymentsCondition.fulfill(
      _conditionId,
      _agreementId,
      _did,
      _planId,
      _lockPaymentCondition,
      _releaseCondition
    );
  }
}
