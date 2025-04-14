// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {FiatSettlementCondition} from '../conditions/FiatSettlementCondition.sol';
import {TransferCreditsCondition} from '../conditions/TransferCreditsCondition.sol';
import {IAgreement} from '../interfaces/IAgreement.sol';
import {IAsset} from '../interfaces/IAsset.sol';
import {INVMConfig} from '../interfaces/INVMConfig.sol';
import {AgreementsStore} from './AgreementsStore.sol';
import {BaseTemplate} from './BaseTemplate.sol';

contract FiatPaymentTemplate is BaseTemplate {
    bytes32 public constant NVM_CONTRACT_NAME = keccak256('FiatPaymentTemplate');

    // keccak256(abi.encode(uint256(keccak256("nevermined.fiatpaymenttemplate.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant FIAT_PAYMENT_TEMPLATE_STORAGE_LOCATION =
        0xe0a010157e7dd2b09e0e2079c38064b9d6a47bc988a33749931879f4b0128000;

    /// @custom:storage-location erc7201:nevermined.fiatpaymenttemplate.storage
    struct FiatPaymentTemplateStorage {
        INVMConfig nvmConfig;
        IAsset assetsRegistry;
        // Conditions required to execute this template
        FiatSettlementCondition fiatSettlementCondition;
        TransferCreditsCondition transferCondition;
    }

    function initialize(
        address _nvmConfigAddress,
        address _authority,
        address _assetsRegistryAddress,
        address _agreementStoreAddress,
        address _fiatSettlementConditionAddress,
        address _transferCondtionAddress
    ) public initializer {
        FiatPaymentTemplateStorage storage $ = _getFiatPaymentTemplateStorage();

        $.nvmConfig = INVMConfig(_nvmConfigAddress);
        $.assetsRegistry = IAsset(_assetsRegistryAddress);
        _getBaseTemplateStorage().agreementStore = AgreementsStore(_agreementStoreAddress);
        $.fiatSettlementCondition = FiatSettlementCondition(_fiatSettlementConditionAddress);
        $.transferCondition = TransferCreditsCondition(_transferCondtionAddress);
        __AccessManagedUUPSUpgradeable_init(_authority);
    }

    function createAgreement(
        bytes32 _seed,
        bytes32 _did,
        uint256 _planId,
        address _creditsReceiver,
        bytes[] memory _params
    ) external {
        FiatPaymentTemplateStorage storage $ = _getFiatPaymentTemplateStorage();
        BaseTemplateStorage storage $bt = _getBaseTemplateStorage();

        // Validate inputs
        if (_seed == bytes32(0)) revert InvalidSeed(_seed);
        if (_did == bytes32(0)) revert InvalidDID(_did);
        if (_planId == 0) revert InvalidPlanId(_planId);

        // Check if the DID & Plan are registered in the AssetsRegistry
        if (!$.assetsRegistry.assetExists(_did)) revert IAsset.AssetNotFound(_did);
        if (!$.assetsRegistry.planExists(_planId)) revert IAsset.PlanNotFound(_planId);

        // Calculate agreementId
        bytes32 agreementId =
            keccak256(abi.encode(NVM_CONTRACT_NAME, msg.sender, _seed, _did, _planId, _creditsReceiver, _params));

        // Check if the agreement is already registered
        IAgreement.Agreement memory agreement = $bt.agreementStore.getAgreement(agreementId);

        if (agreement.lastUpdated != 0) {
            revert IAgreement.AgreementAlreadyRegistered(agreementId);
        }

        // Register the agreement in the AgreementsStore
        bytes32[] memory conditionIds = new bytes32[](2);
        conditionIds[0] =
            $.fiatSettlementCondition.hashConditionId(agreementId, $.fiatSettlementCondition.NVM_CONTRACT_NAME());
        conditionIds[1] = $.transferCondition.hashConditionId(agreementId, $.transferCondition.NVM_CONTRACT_NAME());

        $bt.agreementStore.register(
            agreementId, msg.sender, _did, _planId, conditionIds, new IAgreement.ConditionState[](2), _params
        );

        // Register fiat settlement
        _fiatSettlement(conditionIds[0], agreementId, _planId, msg.sender, _params);
        _transferPlan(conditionIds[1], agreementId, _planId, conditionIds[0], _creditsReceiver);
    }

    function _fiatSettlement(
        bytes32 _conditionId,
        bytes32 _agreementId,
        uint256 _planId,
        address _senderAddress,
        bytes[] memory _params
    ) internal {
        FiatPaymentTemplateStorage storage $ = _getFiatPaymentTemplateStorage();

        $.fiatSettlementCondition.fulfill(_conditionId, _agreementId, _planId, _senderAddress, _params);
    }

    function _transferPlan(
        bytes32 _conditionId,
        bytes32 _agreementId,
        uint256 _planId,
        bytes32 _fiatSettlementCondition,
        address _receiverAddress
    ) internal {
        bytes32[] memory _requiredConditons = new bytes32[](1);
        FiatPaymentTemplateStorage storage $ = _getFiatPaymentTemplateStorage();

        _requiredConditons[0] = _fiatSettlementCondition;
        $.transferCondition.fulfill(_conditionId, _agreementId, _planId, _requiredConditons, _receiverAddress);
    }

    function _getFiatPaymentTemplateStorage() internal pure returns (FiatPaymentTemplateStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := FIAT_PAYMENT_TEMPLATE_STORAGE_LOCATION
        }
    }
}
