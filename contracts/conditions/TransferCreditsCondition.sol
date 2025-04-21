// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {IAgreement} from '../interfaces/IAgreement.sol';
import {IAsset} from '../interfaces/IAsset.sol';
import {INVMConfig} from '../interfaces/INVMConfig.sol';

import {NFT1155Credits} from '../token/NFT1155Credits.sol';
import {NFT1155ExpirableCredits} from '../token/NFT1155ExpirableCredits.sol';
import {TemplateCondition} from './TemplateCondition.sol';
import {ReentrancyGuardTransientUpgradeable} from
    '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';

contract TransferCreditsCondition is ReentrancyGuardTransientUpgradeable, TemplateCondition {
    // keccak256(abi.encode(uint256(keccak256("nevermined.transfercreditscondition.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TRANSFER_CREDITS_CONDITION_STORAGE_LOCATION =
        0x249686b58dc8ad820998e3d83bd78653adb95e2993297822a42d3d4df7f1ae00;

    bytes32 public constant NVM_CONTRACT_NAME = keccak256('TransferCreditsCondition');

    /// @custom:storage-location erc7201:nevermined.transfercreditscondition.storage
    struct TransferCreditsConditionStorage {
        INVMConfig nvmConfig;
        IAsset assetsRegistry;
        IAgreement agreementStore;
    }

    /**
     * @notice Initializes the TransferCreditsCondition contract with required dependencies
     * @param _nvmConfigAddress Address of the NVMConfig contract
     * @param _authority Address of the AccessManager contract
     * @param _assetsRegistryAddress Address of the AssetsRegistry contract
     * @param _agreementStoreAddress Address of the AgreementsStore contract
     */
    function initialize(
        INVMConfig _nvmConfigAddress,
        IAccessManager _authority,
        IAsset _assetsRegistryAddress,
        IAgreement _agreementStoreAddress
    ) external initializer {
        ReentrancyGuardTransientUpgradeable.__ReentrancyGuardTransient_init();
        TransferCreditsConditionStorage storage $ = _getTransferCreditsConditionStorage();

        $.nvmConfig = INVMConfig(_nvmConfigAddress);
        $.assetsRegistry = IAsset(_assetsRegistryAddress);
        $.agreementStore = IAgreement(_agreementStoreAddress);
        __AccessManagedUUPSUpgradeable_init(address(_authority));
    }

    /**
     * @notice Fulfills the transfer credits condition for an agreement
     * @param _conditionId Identifier of the condition to fulfill
     * @param _agreementId Identifier of the agreement
     * @param _planId Identifier of the pricing plan
     * @param _requiredConditions Array of condition identifiers that must be fulfilled first
     * @param _receiverAddress Address that will receive the credits
     * @dev Only registered templates can call this function
     * @dev Checks if required conditions are fulfilled before proceeding
     * @dev Mints credits based on the plan's configuration (expirable or fixed)
     * @dev Reverts for unsupported credit types (dynamic)
     */
    function fulfill(
        bytes32 _conditionId,
        bytes32 _agreementId,
        uint256 _planId,
        bytes32[] memory _requiredConditions,
        address _receiverAddress
    ) external payable nonReentrant {
        TransferCreditsConditionStorage storage $ = _getTransferCreditsConditionStorage();

        // Validate if the account calling this function is a registered template
        if (!$.nvmConfig.isTemplate(msg.sender)) revert INVMConfig.OnlyTemplate(msg.sender);

        // Check if the required conditions (LockPayment) are already fulfilled
        if (!$.agreementStore.areConditionsFulfilled(_agreementId, _conditionId, _requiredConditions)) {
            revert IAgreement.ConditionPreconditionFailed(_agreementId, _conditionId);
        }

        // Check if the plan credits config is correct
        IAsset.Plan memory plan = $.assetsRegistry.getPlan(_planId);

        // FULFILL THE CONDITION first (before external calls)
        $.agreementStore.updateConditionStatus(_agreementId, _conditionId, IAgreement.ConditionState.Fulfilled);

        // Only mint if amount is greater than zero
        if (plan.credits.amount > 0) {
            if (plan.credits.creditsType == IAsset.CreditsType.EXPIRABLE) {
                NFT1155ExpirableCredits nft1155 = NFT1155ExpirableCredits(plan.nftAddress);
                nft1155.mint(_receiverAddress, uint256(_planId), plan.credits.amount, plan.credits.durationSecs, '');
            } else if (plan.credits.creditsType == IAsset.CreditsType.FIXED) {
                NFT1155Credits nft1155 = NFT1155Credits(plan.nftAddress);
                nft1155.mint(_receiverAddress, uint256(_planId), plan.credits.amount, '');
            } else if (plan.credits.creditsType == IAsset.CreditsType.DYNAMIC) {
                revert IAsset.InvalidCreditsType(plan.credits.creditsType);
            } else {
                revert IAsset.InvalidCreditsType(plan.credits.creditsType);
            }
        }
    }

    function _getTransferCreditsConditionStorage() internal pure returns (TransferCreditsConditionStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            $.slot := TRANSFER_CREDITS_CONDITION_STORAGE_LOCATION
        }
    }
}
