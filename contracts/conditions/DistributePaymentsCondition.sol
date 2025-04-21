// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {IAgreement} from '../interfaces/IAgreement.sol';
import {IAsset} from '../interfaces/IAsset.sol';
import {INVMConfig} from '../interfaces/INVMConfig.sol';
import {IVault} from '../interfaces/IVault.sol';

import {TokenUtils} from '../utils/TokenUtils.sol';
import {TemplateCondition} from './TemplateCondition.sol';
import {ReentrancyGuardTransientUpgradeable} from
    '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';

contract DistributePaymentsCondition is ReentrancyGuardTransientUpgradeable, TemplateCondition {
    bytes32 public constant NVM_CONTRACT_NAME = keccak256('DistributePaymentsCondition');

    // keccak256(abi.encode(uint256(keccak256("nevermined.distributepaymentscondition.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant DISTRIBUTE_PAYMENTS_CONDITION_STORAGE_LOCATION =
        0xe41c4b3e2f7bba486623bae88edfd7e81be9c1146d2f719bf139ea3fc6346a00;

    /// @custom:storage-location erc7201:nevermined.distributepaymentscondition.storage
    struct DistributePaymentsConditionStorage {
        INVMConfig nvmConfig;
        IAsset assetsRegistry;
        IAgreement agreementStore;
        IVault vault;
    }

    /**
     * @notice Initializes the DistributePaymentsCondition contract with required dependencies
     * @param _nvmConfigAddress Address of the NVMConfig contract
     * @param _authority Address of the AccessManager contract
     * @param _assetsRegistryAddress Address of the AssetsRegistry contract
     * @param _agreementStoreAddress Address of the AgreementsStore contract
     * @param _vaultAddress Address of the PaymentsVault contract
     */
    function initialize(
        INVMConfig _nvmConfigAddress,
        IAccessManager _authority,
        IAsset _assetsRegistryAddress,
        IAgreement _agreementStoreAddress,
        IVault _vaultAddress
    ) external initializer {
        ReentrancyGuardTransientUpgradeable.__ReentrancyGuardTransient_init();
        DistributePaymentsConditionStorage storage $ = _getDistributePaymentsConditionStorage();

        $.nvmConfig = _nvmConfigAddress;
        $.assetsRegistry = _assetsRegistryAddress;
        $.agreementStore = _agreementStoreAddress;
        $.vault = _vaultAddress;
        __AccessManagedUUPSUpgradeable_init(address(_authority));
    }

    /**
     * @notice Fulfills the distribute payments condition for an agreement
     * @param _conditionId Identifier of the condition to fulfill
     * @param _agreementId Identifier of the agreement
     * @param _planId Identifier of the pricing plan
     * @param _lockCondition Identifier of the lock payment condition
     * @param _releaseCondition Identifier of the release condition (transfer credits)
     * @dev Only registered templates can call this function
     * @dev Checks if lock payment condition is fulfilled before proceeding
     * @dev If release condition is fulfilled, distributes payments to receivers
     * @dev If release condition is not fulfilled, refunds payment to the agreement creator
     */
    function fulfill(
        bytes32 _conditionId,
        bytes32 _agreementId,
        uint256 _planId,
        bytes32 _lockCondition,
        bytes32 _releaseCondition
    ) external payable nonReentrant {
        DistributePaymentsConditionStorage storage $ = _getDistributePaymentsConditionStorage();

        // Validate if the account calling this function is a registered template
        if (!$.nvmConfig.isTemplate(msg.sender)) revert INVMConfig.OnlyTemplate(msg.sender);

        IAgreement.Agreement memory agreement = $.agreementStore.getAgreement(_agreementId);
        if (agreement.lastUpdated == 0) revert IAgreement.AgreementNotFound(_agreementId);

        // Check if the plan credits config is correct
        IAsset.Plan memory plan = $.assetsRegistry.getPlan(_planId);

        if ($.agreementStore.getConditionState(_agreementId, _lockCondition) != IAgreement.ConditionState.Fulfilled) {
            revert IAgreement.ConditionPreconditionFailed(_agreementId, _conditionId);
        }

        // Check if the required conditions (LockPayment) are already fulfilled
        // FULFILL THE CONDITION first (before external calls)
        $.agreementStore.updateConditionStatus(_agreementId, _conditionId, IAgreement.ConditionState.Fulfilled);

        if ($.agreementStore.getConditionState(_agreementId, _releaseCondition) == IAgreement.ConditionState.Fulfilled)
        {
            if (plan.price.tokenAddress == address(0)) {
                _distributeNativeTokenPayments(plan.price.amounts, plan.price.receivers);
            } else {
                _distributeERC20Payments(plan.price.tokenAddress, plan.price.amounts, plan.price.receivers);
            }
        } else {
            // SOME CONDITIONS ABORTED
            // Distribute the payments to the who locked the payment
            uint256[] memory _amountToRefund = new uint256[](1);

            _amountToRefund[0] = TokenUtils.calculateAmountSum(plan.price.amounts);
            address[] memory _originalSender = new address[](1);
            _originalSender[0] = agreement.agreementCreator;

            if (plan.price.tokenAddress == address(0)) {
                _distributeNativeTokenPayments(_amountToRefund, _originalSender);
            } else {
                _distributeERC20Payments(plan.price.tokenAddress, _amountToRefund, _originalSender);
            }
        }
    }

    /**
     * @notice Internal function to distribute native token payments to multiple receivers
     * @param _amounts Array of payment amounts for each receiver
     * @param _receivers Array of payment receiver addresses
     * @dev Withdraws native tokens from the vault to each receiver
     */
    function _distributeNativeTokenPayments(uint256[] memory _amounts, address[] memory _receivers) internal {
        DistributePaymentsConditionStorage storage $ = _getDistributePaymentsConditionStorage();

        uint256 length = _receivers.length;
        for (uint256 i = 0; i < length; i++) {
            $.vault.withdrawNativeToken(_amounts[i], _receivers[i]);
        }
    }

    /**
     * @notice Internal function to distribute ERC20 token payments to multiple receivers
     * @param _erc20TokenAddress Address of the ERC20 token contract
     * @param _amounts Array of payment amounts for each receiver
     * @param _receivers Array of payment receiver addresses
     * @dev Withdraws ERC20 tokens from the vault to each receiver
     */
    function _distributeERC20Payments(
        address _erc20TokenAddress,
        uint256[] memory _amounts,
        address[] memory _receivers
    ) internal {
        DistributePaymentsConditionStorage storage $ = _getDistributePaymentsConditionStorage();

        uint256 length = _receivers.length;
        for (uint256 i = 0; i < length; i++) {
            $.vault.withdrawERC20(_erc20TokenAddress, _amounts[i], _receivers[i]);
        }
    }

    function _getDistributePaymentsConditionStorage()
        internal
        pure
        returns (DistributePaymentsConditionStorage storage $)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            $.slot := DISTRIBUTE_PAYMENTS_CONDITION_STORAGE_LOCATION
        }
    }
}
