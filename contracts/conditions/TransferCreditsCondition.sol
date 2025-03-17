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
import {TokenUtils} from '../utils/TokenUtils.sol';
import {NFT1155Credits} from '../token/NFT1155Credits.sol';

contract TransferCreditsCondition is
  Initializable,
  ReentrancyGuardUpgradeable,
  TemplateCondition,
  TokenUtils
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
    assetsRegistry = IAsset(_assetsRegistryAddress);
    agreementStore = IAgreement(_agreementStoreAddress);
  }

  // function _reinitializeConnections(
  //   address _assetsRegistryAddress,
  //   address _agreementStoreAddress
  // ) public {
  //   if (!nvmConfig.isGovernor(msg.sender))
  //     revert INVMConfig.OnlyGovernor(msg.sender);

  //   assetsRegistry = IAsset(_assetsRegistryAddress);
  //   agreementStore = IAgreement(_agreementStoreAddress);
  // }

  function fulfill(
    bytes32 _conditionId,
    bytes32 _agreementId,
    bytes32 _did,
    bytes32 _planId,
    bytes32[] memory _requiredConditions,
    address _receiverAddress
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

    NFT1155Credits nft1155 = NFT1155Credits(plan.nftAddress);
    nft1155.mint(_receiverAddress, uint256(_did), plan.credits.amount, '');
    // TODO: Implement the logic
    // LOAD NFT1155(plan.nftAddress)
    // IF plan.credits.creditsType == EXPIRABLE
    // ELSE IF plan.credits.creditsType == FIXED
    // ELSE IF plan.credits.creditsType == DYNAMIC
    // ELSE revert

    // FULFILL THE CONDITION
    agreementStore.updateConditionStatus(
      _agreementId,
      _conditionId,
      IAgreement.ConditionState.Fulfilled
    );
  }
}
