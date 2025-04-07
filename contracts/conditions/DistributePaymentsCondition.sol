// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { ReentrancyGuardUpgradeable } from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import { INVMConfig } from '../interfaces/INVMConfig.sol';
import { IAgreement } from '../interfaces/IAgreement.sol';
import { IAsset } from '../interfaces/IAsset.sol';
import { IVault } from '../interfaces/IVault.sol';
import { TemplateCondition } from './TemplateCondition.sol';
import { TokenUtils } from '../utils/TokenUtils.sol';

contract DistributePaymentsCondition is ReentrancyGuardUpgradeable, TemplateCondition {
  bytes32 public constant NVM_CONTRACT_NAME = keccak256('DistributePaymentsCondition');

  INVMConfig internal nvmConfig;
  IAsset internal assetsRegistry;
  IAgreement internal agreementStore;
  IVault internal vault;

  function initialize(
    address _nvmConfigAddress,
    address _assetsRegistryAddress,
    address _agreementStoreAddress,
    address _vaultAddress
  ) public initializer {
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    nvmConfig = INVMConfig(_nvmConfigAddress);
    assetsRegistry = IAsset(_assetsRegistryAddress);
    agreementStore = IAgreement(_agreementStoreAddress);
    vault = IVault(_vaultAddress);
    __Ownable_init(msg.sender);
  }

  function fulfill(
    bytes32 _conditionId,
    bytes32 _agreementId,
    bytes32 /*_did*/,
    uint256 _planId,
    bytes32 _lockCondition,
    bytes32 _releaseCondition
  ) external payable nonReentrant {
    // Validate if the account calling this function is a registered template
    if (!nvmConfig.isTemplate(msg.sender)) revert INVMConfig.OnlyTemplate(msg.sender);

    IAgreement.Agreement memory agreement = agreementStore.getAgreement(_agreementId);
    if (agreement.lastUpdated == 0) revert IAgreement.AgreementNotFound(_agreementId);

    // Check if the DID & Plan are registered in the AssetsRegistry
    // if (!assetsRegistry.assetExists(_did)) revert IAsset.AssetNotFound(_did);
    // if (!assetsRegistry.planExists(_planId)) revert IAsset.PlanNotFound(_planId);

    // Check if the plan credits config is correct
    IAsset.Plan memory plan = assetsRegistry.getPlan(_planId);

    if (
      agreementStore.getConditionState(_agreementId, _lockCondition) !=
      IAgreement.ConditionState.Fulfilled
    ) revert IAgreement.ConditionPreconditionFailed(_agreementId, _conditionId);

    // Check if the required conditions (LockPayment) are already fulfilled
    // FULFILL THE CONDITION first (before external calls)
    agreementStore.updateConditionStatus(
      _agreementId,
      _conditionId,
      IAgreement.ConditionState.Fulfilled
    );

    if (
      agreementStore.getConditionState(_agreementId, _releaseCondition) ==
      IAgreement.ConditionState.Fulfilled
    ) {
      if (plan.price.tokenAddress == address(0))
        _distributeNativeTokenPayments(plan.price.amounts, plan.price.receivers);
      else
        _distributeERC20Payments(plan.price.tokenAddress, plan.price.amounts, plan.price.receivers);
    } else {
      // SOME CONDITIONS ABORTED
      // Distribute the payments to the who locked the payment
      uint256[] memory _amountToRefund = new uint256[](1);

      _amountToRefund[0] = TokenUtils.calculateAmountSum(plan.price.amounts);
      address[] memory _originalSender = new address[](1);
      _originalSender[0] = agreement.agreementCreator;

      if (plan.price.tokenAddress == address(0))
        _distributeNativeTokenPayments(_amountToRefund, _originalSender);
      else _distributeERC20Payments(plan.price.tokenAddress, _amountToRefund, _originalSender);
    }
  }

  function _distributeNativeTokenPayments(
    uint256[] memory _amounts,
    address[] memory _receivers
  ) internal {
    uint256 length = _receivers.length;
    for (uint256 i = 0; i < length; i++) {
      vault.withdrawNativeToken(_amounts[i], _receivers[i]);
    }
  }

  function _distributeERC20Payments(
    address _erc20TokenAddress,
    uint256[] memory _amounts,
    address[] memory _receivers
  ) internal {
    uint256 length = _receivers.length;
    for (uint256 i = 0; i < length; i++) {
      vault.withdrawERC20(_erc20TokenAddress, _amounts[i], _receivers[i]);
    }
  }
}
