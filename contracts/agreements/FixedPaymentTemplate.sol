// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {INVMConfig} from "../interfaces/INVMConfig.sol";
import {AgreementsStore} from "./AgreementsStore.sol";
import {BaseTemplate} from "./BaseTemplate.sol";
import {IAgreement} from "../interfaces/IAgreement.sol";
import {LockPaymentCondition} from "../conditions/LockPaymentCondition.sol";
import {TransferCreditsCondition} from "../conditions/TransferCreditsCondition.sol";
import {DistributePaymentsCondition} from "../conditions/DistributePaymentsCondition.sol";
import {IAsset} from "../interfaces/IAsset.sol";
// import 'hardhat/console.sol';

contract FixedPaymentTemplate is BaseTemplate {
    bytes32 public constant NVM_CONTRACT_NAME = keccak256("FixedPaymentTemplate");

    INVMConfig internal nvmConfig;
    IAsset internal assetsRegistry;

    // Conditions required to execute this template
    LockPaymentCondition internal lockPaymentCondition;
    TransferCreditsCondition internal transferCondition;
    DistributePaymentsCondition internal distributePaymentsCondition;

    function initialize(
        address _nvmConfigAddress,
        address _assetsRegistryAddress,
        address _agreementStoreAddress,
        address _lockPaymentConditionAddress,
        address _transferCondtionAddress,
        address _distributePaymentsCondition
    ) public initializer {
        nvmConfig = INVMConfig(_nvmConfigAddress);
        assetsRegistry = IAsset(_assetsRegistryAddress);
        agreementStore = AgreementsStore(_agreementStoreAddress);
        lockPaymentCondition = LockPaymentCondition(_lockPaymentConditionAddress);
        transferCondition = TransferCreditsCondition(_transferCondtionAddress);
        distributePaymentsCondition = DistributePaymentsCondition(_distributePaymentsCondition);
        __Ownable_init(msg.sender);
    }

    function createAgreement(bytes32 _seed, bytes32 _did, uint256 _planId, bytes[] memory _params) external payable {
        // Validate inputs
        if (_seed == bytes32(0)) revert InvalidSeed(_seed);
        if (_did == bytes32(0)) revert InvalidDID(_did);
        if (_planId == 0) revert InvalidPlanId(_planId);

        // Check if the DID & Plan are registered in the AssetsRegistry
        if (!assetsRegistry.assetExists(_did)) revert IAsset.AssetNotFound(_did);
        if (!assetsRegistry.planExists(_planId)) revert IAsset.PlanNotFound(_planId);

        // Calculate agreementId
        bytes32 agreementId = keccak256(abi.encode(NVM_CONTRACT_NAME, msg.sender, _seed, _did, _planId, _params));

        // Check if the agreement is already registered
        IAgreement.Agreement memory agreement = agreementStore.getAgreement(agreementId);

        if (agreement.lastUpdated != 0) {
            revert IAgreement.AgreementAlreadyRegistered(agreementId);
        }

        // Register the agreement in the AgreementsStore
        bytes32[] memory conditionIds = new bytes32[](3);
        conditionIds[0] = lockPaymentCondition.hashConditionId(agreementId, lockPaymentCondition.NVM_CONTRACT_NAME());
        conditionIds[1] = transferCondition.hashConditionId(agreementId, transferCondition.NVM_CONTRACT_NAME());
        conditionIds[2] =
            distributePaymentsCondition.hashConditionId(agreementId, distributePaymentsCondition.NVM_CONTRACT_NAME());

        agreementStore.register(
            agreementId, msg.sender, _did, _planId, conditionIds, new IAgreement.ConditionState[](3), _params
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
        lockPaymentCondition.fulfill{value: msg.value}(
            _conditionId,
            _agreementId,
            // _did,
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
        _requiredConditons[0] = _lockPaymentCondition;
        transferCondition.fulfill(
            _conditionId,
            _agreementId,
            // _did,
            _planId,
            _requiredConditons,
            _receiverAddress
        );
    }

    function _distributePayments(
        bytes32 _conditionId,
        bytes32 _agreementId,
        // bytes32 _did,
        uint256 _planId,
        bytes32 _lockPaymentCondition,
        bytes32 _releaseCondition
    ) internal {
        distributePaymentsCondition.fulfill(
            _conditionId,
            _agreementId,
            // _did,
            _planId,
            _lockPaymentCondition,
            _releaseCondition
        );
    }
}
