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

contract LockPaymentCondition is ReentrancyGuardUpgradeable, TemplateCondition {
  bytes32 public constant NVM_CONTRACT_NAME = keccak256('LockPaymentCondition');

  INVMConfig internal nvmConfig;
  IAsset internal assetsRegistry;
  IAgreement internal agreementStore;
  IVault internal vault;

  /// The `priceType` given is not supported by the condition
  /// @param priceType The price type supported by the condition
  error UnsupportedPriceTypeOption(IAsset.PriceType priceType);

  /// The `amounts` and `receivers` are incorrect
  /// @param amounts The distribution of the payment amounts
  /// @param receivers The distribution of the payment amounts receivers
  error IncorrectPaymentDistribution(uint256[] amounts, address[] receivers);

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
    address _senderAddress
  ) external payable nonReentrant {
    // Validate if the account calling this function is a registered template
    if (!nvmConfig.isTemplate(msg.sender)) revert INVMConfig.OnlyTemplate(msg.sender);

    // Check if the agreementId is registered in the AssetsRegistry
    if (!agreementStore.agreementExists(_agreementId))
      revert IAgreement.AgreementNotFound(_agreementId);

    // // Check if the DID & Plan are registered in the AssetsRegistry
    // if (!assetsRegistry.assetExists(_did)) revert IAsset.AssetNotFound(_did);
    // if (!assetsRegistry.planExists(_planId)) revert IAsset.PlanNotFound(_planId);

    // Check if the plan config (token, amount) is correct
    IAsset.Plan memory plan = assetsRegistry.getPlan(_planId);

    if (plan.price.priceType == IAsset.PriceType.FIXED_PRICE) {
      // Check if the lengths of amounts and receivers are the same
      if (plan.price.amounts.length != plan.price.receivers.length)
        revert IncorrectPaymentDistribution(plan.price.amounts, plan.price.receivers);
      // Check if the amounts and receivers include the Nevermined fees
      if (!assetsRegistry.areNeverminedFeesIncluded(plan.price.amounts, plan.price.receivers))
        revert IAsset.NeverminedFeesNotIncluded(plan.price.amounts, plan.price.receivers);

      uint256 amountToTransfer = TokenUtils.calculateAmountSum(plan.price.amounts);
      // Only process payment if amount is greater than zero
      if (amountToTransfer > 0) {
        if (plan.price.tokenAddress == address(0)) {
          // Native token payment
          if (msg.value != amountToTransfer)
            revert TokenUtils.InvalidTransactionAmount(msg.value, amountToTransfer);
          vault.depositNativeToken{ value: amountToTransfer }();
        } else {
          // ERC20 deposit
          // Transfer tokens from sender to vault using TokenUtils
          TokenUtils.transferERC20(
            _senderAddress,
            address(vault),
            plan.price.tokenAddress,
            amountToTransfer
          );
          // Record the deposit in the vault
          vault.depositERC20(plan.price.tokenAddress, amountToTransfer, _senderAddress);
        }
      }

      // FULFILL THE CONDITION
      agreementStore.updateConditionStatus(
        _agreementId,
        _conditionId,
        IAgreement.ConditionState.Fulfilled
      );
    } else if (plan.price.priceType == IAsset.PriceType.FIXED_FIAT_PRICE) {
      // Fiat payment can not be locked via LockPaymentCondition but some Oracle integrated with the payment provider (i.e Stripe)
      revert UnsupportedPriceTypeOption(plan.price.priceType);
    } else if (plan.price.priceType == IAsset.PriceType.SMART_CONTRACT_PRICE) {
      // Smart contract payment is not implemented yet
      revert UnsupportedPriceTypeOption(plan.price.priceType);
    } else {
      revert UnsupportedPriceTypeOption(plan.price.priceType);
    }
  }
}
