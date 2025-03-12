// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import {INVMConfig} from '../interfaces/INVMConfig.sol';
import {IAgreement} from '../interfaces/IAgreement.sol';
import {IAsset} from '../interfaces/IAsset.sol';
import {TemplateCondition} from './TemplateCondition.sol';

contract TransferCreditsCondition is
  Initializable,
  ReentrancyGuardUpgradeable,
  TemplateCondition
{
  bytes32 public constant NVM_CONTRACT_NAME =
    keccak256('TransferCreditsCondition');

  INVMConfig internal nvmConfig;
  IAsset internal assetsRegistry;
  IAgreement internal agreementStore;

  function initialize(
    address _nvmConfigAddress,
    address _assetsRegistryAddress,
    address _agreementStoreAddress
  ) public initializer {
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    nvmConfig = INVMConfig(_nvmConfigAddress);
    this._reinitializeConnections(
      _assetsRegistryAddress,
      _agreementStoreAddress
    );
  }

  function _reinitializeConnections(
    address _assetsRegistryAddress,
    address _agreementStoreAddress
  ) public {
    if (!nvmConfig.isGovernor(msg.sender))
      revert INVMConfig.OnlyGovernor(msg.sender);

    assetsRegistry = IAsset(_assetsRegistryAddress);
    agreementStore = IAgreement(_agreementStoreAddress);
  }

  function fulfill(
    bytes32 _conditionId,
    bytes32 _agreementId,
    bytes32 _did,
    bytes32 _planId,
    bytes32[] memory _requiredConditions
  ) external payable nonReentrant {
    // 0. Validate if the account calling this function is a registered template
    if (!nvmConfig.isTemplate(msg.sender))
      revert INVMConfig.OnlyTemplate(msg.sender);

    // 1. Check if the DID & Plan are registered in the AssetsRegistry
    if (!assetsRegistry.assetExists(_did)) revert IAsset.AssetNotFound(_did);
    if (!assetsRegistry.planExists(_planId))
      revert IAsset.PlanNotFound(_planId);

    // 2. Check if the required conditions (LockPayment) are already fulfilled
    if (
      !agreementStore.areConditionsFulfilled(
        _agreementId,
        _conditionId,
        _requiredConditions
      )
    ) revert IAgreement.ConditionPreconditionFailed(_agreementId, _conditionId);

    // 3. Check if the plan credits config is correct
    IAsset.Plan memory plan = assetsRegistry.getPlan(_planId);
    // TODO: Implement the logic
    // LOAD NFT1155(plan.nftAddress)
    // IF plan.credits.creditsType == EXPIRABLE
    // ELSE IF plan.credits.creditsType == FIXED
    // ELSE IF plan.credits.creditsType == DYNAMIC
    // ELSE revert
  }

  function _areNeverminedFeesIncluded(
    uint256[] memory _amounts,
    address[] memory _receivers
  ) internal view returns (bool) {
    if (
      nvmConfig.getNetworkFee() == 0 || nvmConfig.getFeeReceiver() == address(0)
    ) return true;

    uint256 totalAmount = calculateTotalAmount(_amounts);
    if (totalAmount == 0) return true;

    bool _feeReceiverIncluded = false;
    uint256 _receiverIndex = 0;

    for (uint256 i = 0; i < _receivers.length; i++) {
      if (_receivers[i] == nvmConfig.getFeeReceiver()) {
        _feeReceiverIncluded = true;
        _receiverIndex = i;
      }
    }
    if (!_feeReceiverIncluded) return false;

    // Return if fee calculation is correct
    return
      (nvmConfig.getNetworkFee() * totalAmount) /
        nvmConfig.getFeeDenominator() ==
      _amounts[_receiverIndex];
  }

  function calculateTotalAmount(
    uint256[] memory _amounts
  ) public pure returns (uint256) {
    uint256 _totalAmount;
    for (uint256 i; i < _amounts.length; i++) _totalAmount += _amounts[i];
    return _totalAmount;
  }
}
