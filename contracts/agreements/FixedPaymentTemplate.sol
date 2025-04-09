// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { INVMConfig } from "../interfaces/INVMConfig.sol";
import { AgreementsStore } from "./AgreementsStore.sol";
import { BaseTemplate } from "./BaseTemplate.sol";
import { IAgreement } from "../interfaces/IAgreement.sol";
import { LockPaymentCondition } from "../conditions/LockPaymentCondition.sol";
import { TransferCreditsCondition } from "../conditions/TransferCreditsCondition.sol";
import { DistributePaymentsCondition } from "../conditions/DistributePaymentsCondition.sol";
import { IAsset } from "../interfaces/IAsset.sol";

contract FixedPaymentTemplate is BaseTemplate {
  bytes32 public constant NVM_CONTRACT_NAME = keccak256("FixedPaymentTemplate");

  // keccak256(abi.encode(uint256(keccak256("nevermined.fixedpaymenttemplate.storage")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant FIXED_PAYMENT_TEMPLATE_STORAGE_LOCATION =
    0x580af4080cef39e217d40ca96879bdddb787c795da23b8872b06762fc7e20f00;

  /// @custom:storage-location erc7201:nevermined.fixedpaymenttemplate.storage
  struct FixedPaymentTemplateStorage {
    INVMConfig nvmConfig;
    IAsset assetsRegistry;
    // Conditions required to execute this template
    LockPaymentCondition lockPaymentCondition;
    TransferCreditsCondition transferCondition;
    DistributePaymentsCondition distributePaymentsCondition;
  }

  function initialize(
    address _nvmConfigAddress,
    address _authority,
    address _assetsRegistryAddress,
    address _agreementStoreAddress,
    address _lockPaymentConditionAddress,
    address _transferCondtionAddress,
    address _distributePaymentsCondition
  ) public initializer {
    FixedPaymentTemplateStorage storage $ = _getFixedPaymentTemplateStorage();

    $.nvmConfig = INVMConfig(_nvmConfigAddress);
    $.assetsRegistry = IAsset(_assetsRegistryAddress);
    _getBaseTemplateStorage().agreementStore = AgreementsStore(_agreementStoreAddress);
    $.lockPaymentCondition = LockPaymentCondition(_lockPaymentConditionAddress);
    $.transferCondition = TransferCreditsCondition(_transferCondtionAddress);
    $.distributePaymentsCondition = DistributePaymentsCondition(_distributePaymentsCondition);
    __AccessManagedUUPSUpgradeable_init(_authority);
  }

  function createAgreement(
    bytes32 _seed,
    bytes32 _did,
    uint256 _planId,
    bytes[] memory _params
  ) external payable {
    FixedPaymentTemplateStorage storage $ = _getFixedPaymentTemplateStorage();
    BaseTemplateStorage storage $bt = _getBaseTemplateStorage();

    // Validate inputs
    if (_seed == bytes32(0)) revert InvalidSeed(_seed);
    if (_did == bytes32(0)) revert InvalidDID(_did);
    if (_planId == 0) revert InvalidPlanId(_planId);

    // Check if the DID & Plan are registered in the AssetsRegistry
    if (!$.assetsRegistry.assetExists(_did)) revert IAsset.AssetNotFound(_did);
    if (!$.assetsRegistry.planExists(_planId)) revert IAsset.PlanNotFound(_planId);

    // Calculate agreementId
    bytes32 agreementId = keccak256(
      abi.encode(NVM_CONTRACT_NAME, msg.sender, _seed, _did, _planId, _params)
    );

    // Check if the agreement is already registered
    IAgreement.Agreement memory agreement = $bt.agreementStore.getAgreement(agreementId);

    if (agreement.lastUpdated != 0) {
      revert IAgreement.AgreementAlreadyRegistered(agreementId);
    }

    // Register the agreement in the AgreementsStore
    bytes32[] memory conditionIds = new bytes32[](3);
    conditionIds[0] = $.lockPaymentCondition.hashConditionId(
      agreementId,
      $.lockPaymentCondition.NVM_CONTRACT_NAME()
    );
    conditionIds[1] = $.transferCondition.hashConditionId(
      agreementId,
      $.transferCondition.NVM_CONTRACT_NAME()
    );
    conditionIds[2] = $.distributePaymentsCondition.hashConditionId(
      agreementId,
      $.distributePaymentsCondition.NVM_CONTRACT_NAME()
    );

    $bt.agreementStore.register(
      agreementId,
      msg.sender,
      _did,
      _planId,
      conditionIds,
      new IAgreement.ConditionState[](3),
      _params
    );

    // Lock the payment
    _lockPayment(conditionIds[0], agreementId, _planId, msg.sender);
    _transferPlan(conditionIds[1], agreementId, _planId, conditionIds[0], msg.sender);
    _distributePayments(
      conditionIds[2],
      agreementId,
      // _did,
      _planId,
      conditionIds[0],
      conditionIds[1]
    );
  }

  function _lockPayment(
    bytes32 _conditionId,
    bytes32 _agreementId,
    // bytes32 _did,
    uint256 _planId,
    address _senderAddress
  ) internal {
    FixedPaymentTemplateStorage storage $ = _getFixedPaymentTemplateStorage();

    $.lockPaymentCondition.fulfill{ value: msg.value }(
      _conditionId,
      _agreementId,
      _planId,
      _senderAddress
    );
  }

  function _transferPlan(
    bytes32 _conditionId,
    bytes32 _agreementId,
    // bytes32 _did,
    uint256 _planId,
    bytes32 _lockPaymentCondition,
    address _receiverAddress
  ) internal {
    bytes32[] memory _requiredConditons = new bytes32[](1);
    FixedPaymentTemplateStorage storage $ = _getFixedPaymentTemplateStorage();

    _requiredConditons[0] = _lockPaymentCondition;
    $.transferCondition.fulfill(
      _conditionId,
      _agreementId,
      _planId,
      _requiredConditons,
      _receiverAddress
    );
  }

  function _distributePayments(
    bytes32 _conditionId,
    bytes32 _agreementId,
    uint256 _planId,
    bytes32 _lockPaymentCondition,
    bytes32 _releaseCondition
  ) internal {
    FixedPaymentTemplateStorage storage $ = _getFixedPaymentTemplateStorage();

    $.distributePaymentsCondition.fulfill(
      _conditionId,
      _agreementId,
      _planId,
      _lockPaymentCondition,
      _releaseCondition
    );
  }

  function _getFixedPaymentTemplateStorage()
    internal
    pure
    returns (FixedPaymentTemplateStorage storage $)
  {
    // solhint-disable-next-line no-inline-assembly
    assembly ('memory-safe') {
      $.slot := FIXED_PAYMENT_TEMPLATE_STORAGE_LOCATION
    }
  }
}
