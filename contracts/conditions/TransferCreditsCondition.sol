// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {INVMConfig} from "../interfaces/INVMConfig.sol";
import {IAgreement} from "../interfaces/IAgreement.sol";
import {IAsset} from "../interfaces/IAsset.sol";
import {TemplateCondition} from "./TemplateCondition.sol";
import {NFT1155Credits} from "../token/NFT1155Credits.sol";
import {NFT1155ExpirableCredits} from "../token/NFT1155ExpirableCredits.sol";

contract TransferCreditsCondition is ReentrancyGuardUpgradeable, TemplateCondition {
    bytes32 public constant NVM_CONTRACT_NAME = keccak256("TransferCreditsCondition");

    INVMConfig internal nvmConfig;
    IAsset internal assetsRegistry;
    IAgreement internal agreementStore;

    function initialize(address _nvmConfigAddress, address _assetsRegistryAddress, address _agreementStoreAddress)
        public
        initializer
    {
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        nvmConfig = INVMConfig(_nvmConfigAddress);
        assetsRegistry = IAsset(_assetsRegistryAddress);
        agreementStore = IAgreement(_agreementStoreAddress);
        __Ownable_init(msg.sender);
    }

    function fulfill(
        bytes32 _conditionId,
        bytes32 _agreementId,
        uint256 _planId,
        bytes32[] memory _requiredConditions,
        address _receiverAddress
    ) external payable nonReentrant {
        // Validate if the account calling this function is a registered template
        if (!nvmConfig.isTemplate(msg.sender)) revert INVMConfig.OnlyTemplate(msg.sender);

        // Check if the required conditions (LockPayment) are already fulfilled
        if (!agreementStore.areConditionsFulfilled(_agreementId, _conditionId, _requiredConditions)) {
            revert IAgreement.ConditionPreconditionFailed(_agreementId, _conditionId);
        }

        // Check if the plan credits config is correct
        IAsset.Plan memory plan = assetsRegistry.getPlan(_planId);

        // FULFILL THE CONDITION first (before external calls)
        agreementStore.updateConditionStatus(_agreementId, _conditionId, IAgreement.ConditionState.Fulfilled);

        // Only mint if amount is greater than zero
        if (plan.credits.amount > 0) {
            if (plan.credits.creditsType == IAsset.CreditsType.EXPIRABLE) {
                NFT1155ExpirableCredits nft1155 = NFT1155ExpirableCredits(plan.nftAddress);
                nft1155.mint(_receiverAddress, uint256(_planId), plan.credits.amount, plan.credits.durationSecs, "");
            } else if (plan.credits.creditsType == IAsset.CreditsType.FIXED) {
                NFT1155Credits nft1155 = NFT1155Credits(plan.nftAddress);
                nft1155.mint(_receiverAddress, uint256(_planId), plan.credits.amount, "");
            } else if (plan.credits.creditsType == IAsset.CreditsType.DYNAMIC) {
                revert IAsset.InvalidCreditsType(plan.credits.creditsType);
            } else {
                revert IAsset.InvalidCreditsType(plan.credits.creditsType);
            }
        }
    }
}
