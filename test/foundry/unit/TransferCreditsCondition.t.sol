// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.30;

import {TransferCreditsCondition} from '../../../contracts/conditions/TransferCreditsCondition.sol';
import {IAgreement} from '../../../contracts/interfaces/IAgreement.sol';
import {IAsset} from '../../../contracts/interfaces/IAsset.sol';
import {IAccessManaged} from '@openzeppelin/contracts/access/manager/IAccessManaged.sol';

import {BaseTest} from '../common/BaseTest.sol';

contract TransferCreditsConditionTest is BaseTest {
    address public receiver;
    address public template;
    address public user;
    bytes32 public conditionId;
    bytes32 public agreementId;
    bytes32 public did;
    uint256 public planId;

    function setUp() public override {
        super.setUp();

        // Setup addresses
        receiver = makeAddr('receiver');
        template = makeAddr('template');
        user = makeAddr('user');

        // Grant template role
        _grantTemplateRole(template);
    }

    function test_fulfill_fixedCredits() public {
        // Create a plan with fixed credits
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;
        address[] memory receivers = new address[](1);
        receivers[0] = receiver;

        (uint256[] memory finalAmounts, address[] memory finalReceivers) =
            assetsRegistry.addFeesToPaymentsDistribution(amounts, receivers);

        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(0),
            amounts: finalAmounts,
            receivers: finalReceivers,
            contractAddress: address(0)
        });

        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_OWNER,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 100,
            proofRequired: false
        });

        // Register asset and plan
        bytes32 didSeed = bytes32(uint256(1));
        did = assetsRegistry.hashDID(didSeed, address(this));

        vm.prank(address(this));
        assetsRegistry.registerAssetAndPlan(
            didSeed, 'https://nevermined.io', priceConfig, creditsConfig, address(nftCredits)
        );

        // Get the plan ID
        planId = assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(nftCredits), address(this));

        // Create agreement
        bytes32 agreementSeed = bytes32(uint256(2));
        agreementId = keccak256(abi.encode(transferCreditsCondition.NVM_CONTRACT_NAME(), user, agreementSeed, planId));

        // Hash condition ID
        bytes32 contractName = transferCreditsCondition.NVM_CONTRACT_NAME();
        conditionId = transferCreditsCondition.hashConditionId(agreementId, contractName);

        // Register agreement with the condition
        bytes32[] memory conditionIds = new bytes32[](1);
        conditionIds[0] = conditionId;

        IAgreement.ConditionState[] memory conditionStates = new IAgreement.ConditionState[](1);
        conditionStates[0] = IAgreement.ConditionState.Unfulfilled;

        vm.prank(template);
        agreementsStore.register(agreementId, user, planId, conditionIds, conditionStates, new bytes[](0));

        // Fulfill condition
        bytes32[] memory requiredConditions = new bytes32[](0);
        vm.prank(template);
        transferCreditsCondition.fulfill(conditionId, agreementId, planId, requiredConditions, receiver);

        // Verify credits were minted
        assertEq(nftCredits.balanceOf(receiver, planId), 100, 'Fixed credits should be minted to receiver');
    }

    function test_fulfill_expirableCredits() public {
        // Create a plan with expirable credits
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;
        address[] memory receivers = new address[](1);
        receivers[0] = receiver;

        (uint256[] memory finalAmounts, address[] memory finalReceivers) =
            assetsRegistry.addFeesToPaymentsDistribution(amounts, receivers);

        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(0),
            amounts: finalAmounts,
            receivers: finalReceivers,
            contractAddress: address(0)
        });

        uint256 durationSecs = 30 days;
        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.EXPIRABLE,
            redemptionType: IAsset.RedemptionType.ONLY_OWNER,
            durationSecs: durationSecs,
            amount: 100,
            minAmount: 1,
            maxAmount: 100,
            proofRequired: false
        });

        // Register asset and plan
        bytes32 didSeed = bytes32(uint256(3));
        did = assetsRegistry.hashDID(didSeed, address(this));

        vm.prank(address(this));
        assetsRegistry.registerAssetAndPlan(
            didSeed, 'https://nevermined.io', priceConfig, creditsConfig, address(nftExpirableCredits)
        );

        // Get the plan ID
        planId = assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(nftExpirableCredits), address(this));

        // Create agreement
        bytes32 agreementSeed = bytes32(uint256(4));
        agreementId = keccak256(abi.encode(transferCreditsCondition.NVM_CONTRACT_NAME(), user, agreementSeed, planId));

        // Hash condition ID
        bytes32 contractName = transferCreditsCondition.NVM_CONTRACT_NAME();
        conditionId = transferCreditsCondition.hashConditionId(agreementId, contractName);

        // Register agreement with the condition
        bytes32[] memory conditionIds = new bytes32[](1);
        conditionIds[0] = conditionId;

        IAgreement.ConditionState[] memory conditionStates = new IAgreement.ConditionState[](1);
        conditionStates[0] = IAgreement.ConditionState.Unfulfilled;

        vm.prank(template);
        agreementsStore.register(agreementId, user, planId, conditionIds, conditionStates, new bytes[](0));

        // Fulfill condition
        bytes32[] memory requiredConditions = new bytes32[](0);
        vm.prank(template);
        transferCreditsCondition.fulfill(conditionId, agreementId, planId, requiredConditions, receiver);

        // Verify expirable credits were minted
        assertEq(nftExpirableCredits.balanceOf(receiver, planId), 100, 'Expirable credits should be minted to receiver');
    }

    function test_revert_dynamicCredits() public {
        // Create a plan with dynamic credits
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;
        address[] memory receivers = new address[](1);
        receivers[0] = receiver;

        (uint256[] memory finalAmounts, address[] memory finalReceivers) =
            assetsRegistry.addFeesToPaymentsDistribution(amounts, receivers);

        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(0),
            amounts: finalAmounts,
            receivers: finalReceivers,
            contractAddress: address(0)
        });

        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.DYNAMIC,
            redemptionType: IAsset.RedemptionType.ONLY_OWNER,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 100,
            proofRequired: false
        });

        // Register asset and plan
        bytes32 didSeed = bytes32(uint256(5));
        did = assetsRegistry.hashDID(didSeed, address(this));

        vm.prank(address(this));
        assetsRegistry.registerAssetAndPlan(
            didSeed, 'https://nevermined.io', priceConfig, creditsConfig, address(nftCredits)
        );

        // Get the plan ID
        planId = assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(nftCredits), address(this));

        // Create agreement
        bytes32 agreementSeed = bytes32(uint256(6));
        agreementId = keccak256(abi.encode(transferCreditsCondition.NVM_CONTRACT_NAME(), user, agreementSeed, planId));

        // Hash condition ID
        bytes32 contractName = transferCreditsCondition.NVM_CONTRACT_NAME();
        conditionId = transferCreditsCondition.hashConditionId(agreementId, contractName);

        // Register agreement with the condition
        bytes32[] memory conditionIds = new bytes32[](1);
        conditionIds[0] = conditionId;

        IAgreement.ConditionState[] memory conditionStates = new IAgreement.ConditionState[](1);
        conditionStates[0] = IAgreement.ConditionState.Unfulfilled;

        vm.prank(template);
        agreementsStore.register(agreementId, user, planId, conditionIds, conditionStates, new bytes[](0));

        // Try to fulfill condition with dynamic credits
        bytes32[] memory requiredConditions = new bytes32[](0);
        vm.expectRevert(abi.encodeWithSelector(IAsset.InvalidCreditsType.selector, IAsset.CreditsType.DYNAMIC));
        vm.prank(template);
        transferCreditsCondition.fulfill(conditionId, agreementId, planId, requiredConditions, receiver);
    }

    function test_revert_conditionsNotFulfilled() public {
        // Create a plan with fixed credits
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;
        address[] memory receivers = new address[](1);
        receivers[0] = receiver;

        (uint256[] memory finalAmounts, address[] memory finalReceivers) =
            assetsRegistry.addFeesToPaymentsDistribution(amounts, receivers);

        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(0),
            amounts: finalAmounts,
            receivers: finalReceivers,
            contractAddress: address(0)
        });

        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_OWNER,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 100,
            proofRequired: false
        });

        // Register asset and plan
        bytes32 didSeed = bytes32(uint256(7));
        did = assetsRegistry.hashDID(didSeed, address(this));

        vm.prank(address(this));
        assetsRegistry.registerAssetAndPlan(
            didSeed, 'https://nevermined.io', priceConfig, creditsConfig, address(nftCredits)
        );

        // Get the plan ID
        planId = assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(nftCredits), address(this));

        // Create agreement
        bytes32 agreementSeed = bytes32(uint256(8));
        agreementId = keccak256(abi.encode(transferCreditsCondition.NVM_CONTRACT_NAME(), user, agreementSeed, planId));

        // Hash condition ID
        bytes32 contractName = transferCreditsCondition.NVM_CONTRACT_NAME();
        conditionId = transferCreditsCondition.hashConditionId(agreementId, contractName);

        // Create a required condition ID that won't be fulfilled
        bytes32 requiredConditionId = keccak256('required-condition');

        // Register agreement with both conditions
        bytes32[] memory conditionIds = new bytes32[](2);
        conditionIds[0] = conditionId;
        conditionIds[1] = requiredConditionId;

        IAgreement.ConditionState[] memory conditionStates = new IAgreement.ConditionState[](2);
        conditionStates[0] = IAgreement.ConditionState.Unfulfilled;
        conditionStates[1] = IAgreement.ConditionState.Unfulfilled;

        vm.prank(template);
        agreementsStore.register(agreementId, user, planId, conditionIds, conditionStates, new bytes[](0));

        // Try to fulfill condition without fulfilling the required condition
        bytes32[] memory requiredConditions = new bytes32[](1);
        requiredConditions[0] = requiredConditionId;

        vm.expectRevert(
            abi.encodeWithSelector(IAgreement.ConditionPreconditionFailed.selector, agreementId, conditionId)
        );
        vm.prank(template);
        transferCreditsCondition.fulfill(conditionId, agreementId, planId, requiredConditions, receiver);

        // Verify no credits were minted
        assertEq(
            nftCredits.balanceOf(receiver, planId), 0, 'No credits should be minted when conditions are not fulfilled'
        );
    }
}
