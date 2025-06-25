// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.30;

import {AssetsRegistry} from '../../../contracts/AssetsRegistry.sol';
import {IAsset} from '../../../contracts/interfaces/IAsset.sol';
import {IFeeController} from '../../../contracts/interfaces/IFeeController.sol';

import {IHook} from '../../../contracts/interfaces/IHook.sol';
import {INVMConfig} from '../../../contracts/interfaces/INVMConfig.sol';
import {IAccessManaged} from '@openzeppelin/contracts/access/manager/IAccessManaged.sol';
import {console2} from 'forge-std/console2.sol';

import {AssetsRegistryV2} from '../../../contracts/mock/AssetsRegistryV2.sol';
import {BaseTest} from '../common/BaseTest.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {ProtocolStandardFees} from '../../../contracts/fees/ProtocolStandardFees.sol';
import {IERC165} from '@openzeppelin/contracts/utils/introspection/IERC165.sol';

contract AssetsRegistryTest is BaseTest {
    bytes32 public testDid;
    string constant URL = 'https://nevermined.io';

    function setUp() public override {
        super.setUp();
        testDid = keccak256(abi.encodePacked('test-did', block.timestamp));
    }

    function test_hashDID() public view {
        bytes32 did = assetsRegistry.hashDID('test-seed', address(this));
        assertFalse(did == bytes32(0));
    }

    function test_getNonExistentAsset() public view {
        bytes32 did = keccak256(abi.encodePacked('non-existent'));
        IAsset.DIDAsset memory asset = assetsRegistry.getAsset(did);
        assertEq(asset.lastUpdated, 0);
    }

    function test_transferAssetOwnership() public {
        address newOwner = makeAddr('newOwner');
        uint256 planId = _createPlan();
        bytes32 did = _registerAsset(planId);
        // Verify initial owner
        IAsset.DIDAsset memory asset = assetsRegistry.getAsset(did);
        assertEq(asset.owner, address(this));

        // Transfer ownership
        vm.prank(address(this));
        assetsRegistry.transferAssetOwnership(did, newOwner);

        // Verify new owner
        asset = assetsRegistry.getAsset(did);
        assertEq(asset.owner, newOwner);
    }

    function test_transferAssetOwnership_revertIfNotOwner() public {
        // Try to transfer ownership from non-owner account
        address nonOwner = makeAddr('nonOwner');
        uint256 planId = _createPlan();
        bytes32 did = _registerAsset(planId);

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(IAsset.NotAssetOwner.selector, did, nonOwner, address(this)));
        assetsRegistry.transferAssetOwnership(did, nonOwner);
    }

    function test_transferPlanOwnership() public {
        address newOwner = makeAddr('newOwner');
        uint256 planId = _createPlan();

        // Verify initial owner
        IAsset.Plan memory plan = assetsRegistry.getPlan(planId);
        assertEq(plan.owner, address(this));

        // Transfer ownership
        vm.prank(address(this));
        assetsRegistry.transferPlanOwnership(planId, newOwner);

        // Verify new owner
        plan = assetsRegistry.getPlan(planId);
        assertEq(plan.owner, newOwner);
    }

    function test_transferPlanOwnership_revertIfNotOwner() public {
        // Try to transfer ownership from non-owner account
        address nonOwner = makeAddr('nonOwner');
        uint256 planId = _createPlan();

        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(IAsset.NotPlanOwner.selector, planId, nonOwner, address(this)));
        assetsRegistry.transferPlanOwnership(planId, nonOwner);
    }

    function test_registerAsset() public {
        // Create a valid plan first
        uint256 planId = _createPlan();

        uint256[] memory planIds = new uint256[](1);
        planIds[0] = planId;

        // Get the DID that will be generated
        bytes32 did = assetsRegistry.hashDID('test-did', owner);

        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit IAsset.AssetRegistered(did, owner);

        assetsRegistry.register('test-did', URL, planIds);

        IAsset.DIDAsset memory asset = assetsRegistry.getAsset(did);
        assertTrue(asset.lastUpdated > 0);
    }

    function test_cannotRegisterIfPlanDoesntExist() public {
        uint256[] memory planIds = new uint256[](1);
        planIds[0] = 999;

        vm.expectPartialRevert(IAsset.PlanNotFound.selector);
        assetsRegistry.register('test-did', 'https://example.com', planIds);
    }

    function test_cannotCreatePlanIfWrongNFTAddress() public {
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 999;
        address[] memory _receivers = new address[](1);
        _receivers[0] = address(this);

        // Create a dummy plan for testing
        IAsset.Plan memory plan = IAsset.Plan({
            owner: address(this),
            price: IAsset.PriceConfig({
                priceType: IAsset.PriceType.FIXED_FIAT_PRICE,
                tokenAddress: address(0),
                amounts: _amounts,
                receivers: _receivers,
                contractAddress: address(0),
                feeController: IFeeController(address(0))
            }),
            credits: IAsset.CreditsConfig({
                creditsType: IAsset.CreditsType.FIXED,
                redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
                durationSecs: 0,
                amount: 100,
                proofRequired: false,
                minAmount: 1,
                maxAmount: 1,
                nftAddress: address(0)
            }),
            lastUpdated: block.timestamp
        });

        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_FIAT_PRICE,
            tokenAddress: address(0),
            amounts: _amounts,
            receivers: _receivers,
            contractAddress: address(0),
            feeController: IFeeController(address(0))
        });
        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
            durationSecs: 0,
            amount: 100,
            proofRequired: false,
            minAmount: 1,
            maxAmount: 1,
            nftAddress: address(0)
        });

        (uint256[] memory amounts, address[] memory receivers) =
            assetsRegistry.addFeesToPaymentsDistribution(priceConfig, creditsConfig);

        plan.price.amounts = amounts;
        plan.price.receivers = receivers;

        vm.expectPartialRevert(IAsset.InvalidNFTAddress.selector);
        assetsRegistry.createPlan(priceConfig, creditsConfig);
    }

    function test_canRegisterAssetWithoutPlans() public {
        uint256[] memory emptyPlans = new uint256[](0);

        vm.prank(owner);

        assetsRegistry.register('test-did', URL, emptyPlans);
    }

    function test_hashPlanId() public view {
        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(0),
            amounts: new uint256[](1),
            receivers: new address[](1),
            contractAddress: address(0),
            feeController: IFeeController(address(0))
        });
        priceConfig.amounts[0] = 100;
        priceConfig.receivers[0] = owner;

        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 1,
            proofRequired: false,
            nftAddress: address(nftCredits)
        });

        uint256 planId = assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(this));
        assertTrue(planId > 0);
    }

    function test_getNonExistentPlan() public view {
        uint256 planId = 1;
        IAsset.Plan memory plan = assetsRegistry.getPlan(planId);
        assertEq(plan.lastUpdated, 0);
    }

    function test_addFeesToPaymentsDistribution() public {
        uint256[] memory amounts = new uint256[](2);
        address[] memory receivers = new address[](2);

        amounts[0] = 1000;
        amounts[1] = 2000;
        receivers[0] = address(0x04005BBD24EC13D5920aD8845C55496A4C24c466);
        receivers[1] = address(0x9Aa6E515c64fC46FC8B20bA1Ca7f9B26ff404548);

        // Create a dummy plan for testing
        IAsset.Plan memory plan = IAsset.Plan({
            owner: address(this),
            price: IAsset.PriceConfig({
                priceType: IAsset.PriceType.FIXED_PRICE,
                tokenAddress: address(0),
                amounts: amounts,
                receivers: receivers,
                contractAddress: address(0),
                feeController: IFeeController(address(0))
            }),
            credits: IAsset.CreditsConfig({
                creditsType: IAsset.CreditsType.FIXED,
                redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
                durationSecs: 0,
                amount: 100,
                minAmount: 1,
                maxAmount: 1,
                proofRequired: false,
                nftAddress: address(nftCredits)
            }),
            lastUpdated: block.timestamp
        });

        // Register the plan
        uint256 planId = assetsRegistry.createPlan(plan.price, plan.credits);

        bool areFeesIncluded = assetsRegistry.areNeverminedFeesIncluded(planId);
        assertTrue(areFeesIncluded);
    }

    function test_addPlanToAsset_assetNotFound() public {
        vm.expectPartialRevert(IAsset.AssetNotFound.selector);
        assetsRegistry.addPlanToAsset(bytes32(0), 1);
    }

    function test_addPlanToAsset_notOwner() public {
        // Register an asset first
        uint256 planId = _createPlan();
        bytes32 did = _registerAsset(planId);

        uint256 anotherPlan = _createPlan(999);

        // Try to add a plan as a non-owner
        address nonOwner = makeAddr('nonOwner');
        vm.prank(nonOwner);
        vm.expectPartialRevert(IAsset.NotAssetOwner.selector);
        assetsRegistry.addPlanToAsset(did, anotherPlan);
    }

    function test_addPlanToAsset_success() public {
        // Register an asset first
        uint256 planId = _createPlan();
        bytes32 did = _registerAsset(planId);

        uint256 anotherPlan = _createPlan(999);

        // Add the second plan to the asset
        assetsRegistry.addPlanToAsset(did, anotherPlan);

        // Verify that the plan was added
        IAsset.DIDAsset memory asset = assetsRegistry.getAsset(did);
        assertEq(asset.plans.length, 2);
        assertEq(asset.plans[0], planId);
        assertEq(asset.plans[1], anotherPlan);
    }

    function test_addPlanToAsset_noChangeIfPlanAlreadyInAsset() public {
        // Register an asset first
        uint256 planId = _createPlan();
        bytes32 did = _registerAsset(planId);

        // Get initial state
        IAsset.DIDAsset memory initialAsset = assetsRegistry.getAsset(did);
        uint256 initialPlanCount = initialAsset.plans.length;
        uint256[] memory initialPlans = initialAsset.plans;

        // Try to add the same plan again
        assetsRegistry.addPlanToAsset(did, planId);

        // Get final state
        IAsset.DIDAsset memory finalAsset = assetsRegistry.getAsset(did);
        uint256 finalPlanCount = finalAsset.plans.length;
        uint256[] memory finalPlans = finalAsset.plans;

        // Verify no changes occurred
        assertEq(finalPlanCount, initialPlanCount, 'Plan count should not change');
        assertEq(finalPlans[0], initialPlans[0], 'Plan ID should remain the same');
    }

    function test_addPlanToAsset_noChangeIfPlanAlreadyInAsset_multiplePlans() public {
        // Register an asset first
        uint256 planId1 = _createPlan();
        uint256 planId2 = _createPlan(999);
        bytes32 did = _registerAsset(planId1);

        // Add second plan
        assetsRegistry.addPlanToAsset(did, planId2);

        // Get initial state
        IAsset.DIDAsset memory initialAsset = assetsRegistry.getAsset(did);
        uint256 initialPlanCount = initialAsset.plans.length;
        uint256[] memory initialPlans = initialAsset.plans;

        // Try to add the first plan again
        assetsRegistry.addPlanToAsset(did, planId1);

        // Get final state
        IAsset.DIDAsset memory finalAsset = assetsRegistry.getAsset(did);
        uint256 finalPlanCount = finalAsset.plans.length;
        uint256[] memory finalPlans = finalAsset.plans;

        // Verify no changes occurred
        assertEq(finalPlanCount, initialPlanCount, 'Plan count should not change');
        assertEq(finalPlans[0], initialPlans[0], 'First plan ID should remain the same');
        assertEq(finalPlans[1], initialPlans[1], 'Second plan ID should remain the same');
    }

    function test_removePlanFromAsset_assetNotFound() public {
        vm.expectPartialRevert(IAsset.AssetNotFound.selector);
        assetsRegistry.removePlanFromAsset(bytes32(0), 1);
    }

    function test_removePlanFromAsset_notOwner() public {
        // Register an asset first
        uint256 planId = _createPlan();
        bytes32 did = _registerAsset(planId);

        address nonOwner = makeAddr('nonOwner');
        vm.prank(nonOwner);
        vm.expectPartialRevert(IAsset.NotAssetOwner.selector);
        assetsRegistry.removePlanFromAsset(did, planId);
    }

    function test_removePlanFromAsset_success() public {
        // Register an asset first
        uint256 planId = _createPlan();
        bytes32 did = _registerAsset(planId);

        uint256 planId2 = _createPlan(999);
        uint256 planId3 = _createPlan(998);
        uint256 planId4 = _createPlan(997);

        // Add the second plan to the asset
        assetsRegistry.addPlanToAsset(did, planId2);
        assetsRegistry.addPlanToAsset(did, planId3);
        assetsRegistry.addPlanToAsset(did, planId4);

        // Verify that the plan was added
        IAsset.DIDAsset memory asset = assetsRegistry.getAsset(did);
        assertEq(asset.plans.length, 4);
        console2.log(planId, planId2, planId3, planId4);

        // Remove the second plan from the asset
        assetsRegistry.removePlanFromAsset(did, planId2);
        asset = assetsRegistry.getAsset(did);
        assertEq(asset.plans.length, 3);
        console2.log(asset.plans[0], asset.plans[1], asset.plans[2]);

        assertEq(asset.plans[0], planId);
        assertEq(asset.plans[1], planId4);
        assertEq(asset.plans[2], planId3);
    }

    function test_replacePlanFromAsset_assetNotFound() public {
        uint256[] memory noPlans = new uint256[](0);
        vm.expectPartialRevert(IAsset.AssetNotFound.selector);
        assetsRegistry.replacePlansForAsset(bytes32(0), noPlans);
    }

    function test_replacePlanFromAsset_notOwner() public {
        // Register an asset first
        uint256 planId = _createPlan();
        uint256 planId2 = _createPlan(999);
        bytes32 did = _registerAsset(planId);

        uint256[] memory newPlans = new uint256[](2);
        newPlans[0] = planId;
        newPlans[1] = planId2;

        address nonOwner = makeAddr('nonOwner');
        vm.prank(nonOwner);
        vm.expectPartialRevert(IAsset.NotAssetOwner.selector);
        assetsRegistry.replacePlansForAsset(did, newPlans);
    }

    function test_replaceEmptyArrayPlans_success() public {
        uint256 planId = _createPlan();
        bytes32 did = _registerAsset(planId);

        uint256[] memory noPlans = new uint256[](0);
        assetsRegistry.replacePlansForAsset(did, noPlans);
        IAsset.DIDAsset memory asset = assetsRegistry.getAsset(did);

        assertEq(asset.plans.length, 0);
    }

    function test_replacePlans_success() public {
        uint256 planId = _createPlan();
        uint256 planId2 = _createPlan(999);
        bytes32 did = _registerAsset(planId);

        uint256[] memory newPlans = new uint256[](2);
        newPlans[0] = planId;
        newPlans[1] = planId2;
        assetsRegistry.replacePlansForAsset(did, newPlans);
        IAsset.DIDAsset memory asset = assetsRegistry.getAsset(did);

        assertEq(asset.plans.length, 2);
    }

    function test_upgraderShouldBeAbleToUpgradeAfterDelay() public {
        string memory newVersion = '2.0.0';

        uint48 upgradeTime = uint48(block.timestamp + UPGRADE_DELAY);

        AssetsRegistryV2 assetsRegistryV2Impl = new AssetsRegistryV2();

        vm.prank(upgrader);
        accessManager.schedule(
            address(assetsRegistry),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(assetsRegistryV2Impl), bytes(''))),
            upgradeTime
        );

        vm.warp(upgradeTime);

        vm.prank(upgrader);
        accessManager.execute(
            address(assetsRegistry),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(assetsRegistryV2Impl), bytes('')))
        );

        AssetsRegistryV2 assetsRegistryV2 = AssetsRegistryV2(address(assetsRegistry));

        vm.prank(governor);
        assetsRegistryV2.initializeV2(newVersion);

        assertEq(assetsRegistryV2.getVersion(), newVersion);
    }

    function test_createPlan_revertIfPlanAlreadyRegistered() public {
        // Create a plan first
        uint256 planId = _createPlan(0);

        IAsset.Plan memory plan = assetsRegistry.getPlan(planId);

        vm.expectRevert(abi.encodeWithSelector(IAsset.PlanAlreadyRegistered.selector, planId));
        assetsRegistry.createPlan(plan.price, plan.credits, 0);
    }

    function test_createPlan_revertIfInvalidNFTAddress() public {
        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(0),
            amounts: new uint256[](1),
            receivers: new address[](1),
            contractAddress: address(0),
            feeController: IFeeController(address(0))
        });
        priceConfig.amounts[0] = 100;
        priceConfig.receivers[0] = owner;

        // Use a non-NFT1155 contract address
        address nonNFTAddress = address(this);

        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 1,
            proofRequired: false,
            nftAddress: nonNFTAddress
        });

        vm.expectRevert(abi.encodeWithSelector(IAsset.InvalidNFTAddress.selector, nonNFTAddress));
        assetsRegistry.createPlan(priceConfig, creditsConfig, 0);
    }

    function test_createPlan_revertIfNeverminedFeesNotIncluded() public {
        // Setup NVM Fee Receiver
        vm.prank(governor);
        nvmConfig.setFeeReceiver(nvmFeeReceiver);

        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(0),
            amounts: new uint256[](1),
            receivers: new address[](1),
            contractAddress: address(0),
            feeController: IFeeController(address(0))
        });
        // Set amounts and receivers without including Nevermined fees
        priceConfig.amounts[0] = 100;
        priceConfig.receivers[0] = address(1);

        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 1,
            proofRequired: false,
            nftAddress: address(nftCredits)
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IAsset.NeverminedFeesNotIncluded.selector, priceConfig.amounts, priceConfig.receivers
            )
        );
        assetsRegistry.createPlan(priceConfig, creditsConfig);
    }

    function test_createPlan_successWithNeverminedFees() public {
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 100;
        address[] memory _receivers = new address[](1);
        _receivers[0] = owner;

        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(0),
            amounts: _amounts,
            receivers: _receivers,
            contractAddress: address(0),
            feeController: IFeeController(address(0))
        });
        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 1,
            proofRequired: false,
            nftAddress: address(nftCredits)
        });

        (uint256[] memory amounts, address[] memory receivers) =
            assetsRegistry.addFeesToPaymentsDistribution(priceConfig, creditsConfig);

        priceConfig.amounts = amounts;
        priceConfig.receivers = receivers;

        // Should not revert
        assetsRegistry.createPlan(priceConfig, creditsConfig);
    }

    function test_createPlan_successWithNonFixedPrice() public {
        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_FIAT_PRICE, // Not FIXED_PRICE
            tokenAddress: address(0),
            amounts: new uint256[](1),
            receivers: new address[](1),
            contractAddress: address(0),
            feeController: IFeeController(address(0))
        });
        priceConfig.amounts[0] = 100;
        priceConfig.receivers[0] = owner;

        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 1,
            proofRequired: false,
            nftAddress: address(nftCredits)
        });

        // Should not revert even without Nevermined fees since it's not FIXED_PRICE
        assetsRegistry.createPlan(priceConfig, creditsConfig);
    }

    function test_assetExists() public {
        // Initially asset should not exist
        assertFalse(assetsRegistry.assetExists(testDid));

        // Register an asset
        uint256 planId = _createPlan();
        bytes32 did = _registerAsset(planId);

        // Now asset should exist
        assertTrue(assetsRegistry.assetExists(did));
    }

    function test_registerAsset_revertIfInvalidURL() public {
        uint256 planId = _createPlan();
        uint256[] memory planIds = new uint256[](1);
        planIds[0] = planId;

        vm.expectRevert(abi.encodeWithSelector(IAsset.InvalidURL.selector, ''));
        assetsRegistry.register('', '', planIds);
    }

    function test_registerAsset_revertIfDIDAlreadyRegistered() public {
        uint256 planId = _createPlan();
        uint256[] memory planIds = new uint256[](1);
        planIds[0] = planId;

        // Register asset first time
        bytes32 did = assetsRegistry.hashDID('test-did', owner);
        vm.prank(owner);
        assetsRegistry.register('test-did', URL, planIds);

        // Try to register same asset again
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IAsset.DIDAlreadyRegistered.selector, did));
        assetsRegistry.register('test-did', URL, planIds);
    }

    function test_createPlan_revertIfPriceConfigInvalidAmountsOrReceivers() public {
        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(0),
            amounts: new uint256[](2), // Different length arrays
            receivers: new address[](1),
            contractAddress: address(0),
            feeController: IFeeController(address(0))
        });
        priceConfig.amounts[0] = 100;
        priceConfig.amounts[1] = 200;
        priceConfig.receivers[0] = owner;

        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 1,
            proofRequired: false,
            nftAddress: address(nftCredits)
        });

        vm.expectRevert(IAsset.PriceConfigInvalidAmountsOrReceivers.selector);
        assetsRegistry.createPlan(priceConfig, creditsConfig);
    }

    function test_addPlanToAsset_revertIfPlanNotFound() public {
        uint256 planId = _createPlan();
        bytes32 did = _registerAsset(planId);

        // Try to add non-existent plan
        uint256 nonExistentPlanId = 999;
        vm.expectRevert(abi.encodeWithSelector(IAsset.PlanNotFound.selector, nonExistentPlanId));
        assetsRegistry.addPlanToAsset(did, nonExistentPlanId);
    }

    function test_removePlanFromAsset_revertIfPlanNotInAsset() public {
        uint256 planId = _createPlan();
        bytes32 did = _registerAsset(planId);

        // Try to remove a plan that wasn't added to the asset
        uint256 otherPlanId = _createPlan(999);
        vm.expectRevert(abi.encodeWithSelector(IAsset.PlanNotInAsset.selector, did, otherPlanId));
        assetsRegistry.removePlanFromAsset(did, otherPlanId);
    }

    function test_removePlanFromAsset_revertIfAssetNotFound() public {
        uint256 planId = _createPlan();
        bytes32 nonExistentDid = keccak256(abi.encodePacked('non-existent'));

        vm.expectRevert(abi.encodeWithSelector(IAsset.AssetNotFound.selector, nonExistentDid));
        assetsRegistry.removePlanFromAsset(nonExistentDid, planId);
    }

    function test_addFeesToPaymentsDistribution_revertIfMultipleFeeReceivers() public {
        // Setup NVM Fee Receiver
        vm.prank(governor);
        nvmConfig.setFeeReceiver(nvmFeeReceiver);

        uint256[] memory amounts = new uint256[](2);
        address[] memory receivers = new address[](2);

        // Set up two receivers with the same address as nvmFeeReceiver
        amounts[0] = 1000;
        amounts[1] = 2000;
        receivers[0] = nvmFeeReceiver;
        receivers[1] = nvmFeeReceiver;

        // Create a dummy plan for testing
        IAsset.Plan memory plan = IAsset.Plan({
            owner: address(this),
            price: IAsset.PriceConfig({
                priceType: IAsset.PriceType.FIXED_PRICE,
                tokenAddress: address(0),
                amounts: amounts,
                receivers: receivers,
                contractAddress: address(0),
                feeController: IFeeController(address(0))
            }),
            credits: IAsset.CreditsConfig({
                creditsType: IAsset.CreditsType.FIXED,
                redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
                durationSecs: 0,
                amount: 100,
                minAmount: 1,
                maxAmount: 1,
                proofRequired: false,
                nftAddress: address(nftCredits)
            }),
            lastUpdated: block.timestamp
        });

        vm.expectRevert(IAsset.MultipleFeeReceiversIncluded.selector);
        assetsRegistry.createPlan(plan.price, plan.credits);
    }

    function test_assetExists_revertIfAssetNotFound() public view {
        bytes32 nonExistentDid = keccak256(abi.encodePacked('non-existent'));
        assertFalse(assetsRegistry.assetExists(nonExistentDid));
    }

    function test_replacePlansForAsset_revertIfPlanNotFound() public {
        // Register an asset first
        uint256 planId = _createPlan();
        bytes32 did = _registerAsset(planId);

        // Create array with non-existent plan (use a very large number to ensure it's greater than planId)
        uint256[] memory newPlans = new uint256[](2);
        newPlans[0] = planId;
        newPlans[1] = type(uint256).max; // Non-existent plan, but greater than planId

        vm.expectRevert(abi.encodeWithSelector(IAsset.PlanNotFound.selector, type(uint256).max));
        assetsRegistry.replacePlansForAsset(did, newPlans);
    }

    function test_transferPlanOwnership_revertIfPlanNotFound() public {
        uint256 nonExistentPlanId = 999;
        address newOwner = makeAddr('newOwner');

        vm.expectRevert(abi.encodeWithSelector(IAsset.PlanNotFound.selector, nonExistentPlanId));
        assetsRegistry.transferPlanOwnership(nonExistentPlanId, newOwner);
    }

    function test_transferAssetOwnership_revertIfAssetNotFound() public {
        bytes32 nonExistentDid = keccak256(abi.encodePacked('non-existent'));
        address newOwner = makeAddr('newOwner');

        vm.expectRevert(abi.encodeWithSelector(IAsset.AssetNotFound.selector, nonExistentDid));
        assetsRegistry.transferAssetOwnership(nonExistentDid, newOwner);
    }

    function test_addFeesToPaymentsDistribution_whenFeesNotIncluded() public {
        // Setup NVM Fee Receiver
        vm.prank(governor);
        nvmConfig.setFeeReceiver(nvmFeeReceiver);

        uint256[] memory amounts = new uint256[](2);
        address[] memory receivers = new address[](2);

        // Set up receivers without nvmFeeReceiver
        amounts[0] = 1000;
        amounts[1] = 2000;
        receivers[0] = address(1);
        receivers[1] = address(2);

        // Create a dummy plan for testing
        IAsset.Plan memory plan = IAsset.Plan({
            owner: address(this),
            price: IAsset.PriceConfig({
                priceType: IAsset.PriceType.FIXED_PRICE,
                tokenAddress: address(0),
                amounts: amounts,
                receivers: receivers,
                contractAddress: address(0),
                feeController: IFeeController(address(0))
            }),
            credits: IAsset.CreditsConfig({
                creditsType: IAsset.CreditsType.FIXED,
                redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
                durationSecs: 0,
                amount: 100,
                minAmount: 1,
                maxAmount: 1,
                proofRequired: false,
                nftAddress: address(nftCredits)
            }),
            lastUpdated: block.timestamp
        });

        (uint256[] memory newAmounts, address[] memory newReceivers) =
            assetsRegistry.addFeesToPaymentsDistribution(plan.price, plan.credits);

        // Verify that fees were added
        assertEq(newAmounts.length, amounts.length + 1, 'Should add one more amount for fees');
        assertEq(newReceivers.length, receivers.length + 1, 'Should add one more receiver for fees');

        // Verify that the last receiver is the nvmFeeReceiver
        assertEq(newReceivers[newReceivers.length - 1], nvmFeeReceiver, 'Last receiver should be nvmFeeReceiver');

        // Verify that the amounts are correctly distributed
        uint256 totalOriginalAmount = amounts[0] + amounts[1];
        uint256 feeAmount = (totalOriginalAmount * 10000) / 1000000; // 1% fee
        assertEq(newAmounts[newAmounts.length - 1], feeAmount, 'Fee amount should be correct');

        // Verify that the original amounts are preserved
        for (uint256 i = 0; i < amounts.length; i++) {
            assertEq(newAmounts[i], amounts[i], 'Original amounts should be preserved');
            assertEq(newReceivers[i], receivers[i], 'Original receivers should be preserved');
        }
    }

    function test_areNeverminedFeesIncluded_feeReceiverIncludedButAmountTooLow() public {
        // Setup NVM Fee Receiver
        vm.prank(governor);
        nvmConfig.setFeeReceiver(nvmFeeReceiver); // 10% fee

        uint256[] memory amounts = new uint256[](2);
        address[] memory receivers = new address[](2);

        // Set up receivers with nvmFeeReceiver but incorrect amount
        amounts[0] = 1000;
        amounts[1] = 50; // Too low fee amount (should be 100 for 10% of 1000)
        receivers[0] = address(1);
        receivers[1] = nvmFeeReceiver;

        // Create a dummy plan for testing
        IAsset.Plan memory plan = IAsset.Plan({
            owner: address(this),
            price: IAsset.PriceConfig({
                priceType: IAsset.PriceType.FIXED_PRICE,
                tokenAddress: address(0),
                amounts: amounts,
                receivers: receivers,
                contractAddress: address(0),
                feeController: IFeeController(address(0))
            }),
            credits: IAsset.CreditsConfig({
                creditsType: IAsset.CreditsType.FIXED,
                redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
                durationSecs: 0,
                amount: 100,
                minAmount: 1,
                maxAmount: 1,
                proofRequired: false,
                nftAddress: address(nftCredits)
            }),
            lastUpdated: block.timestamp
        });

        vm.expectPartialRevert(IAsset.NeverminedFeesNotIncluded.selector);
        assetsRegistry.createPlan(plan.price, plan.credits);
    }

    function test_addFiatFeesToPaymentsDistribution() public {
        // Setup NVM Fee Receiver
        vm.prank(governor);
        nvmConfig.setFeeReceiver(nvmFeeReceiver);

        uint256[] memory _amounts = new uint256[](1);
        address[] memory _receivers = new address[](1);

        _amounts[0] = 5000;
        // amounts[1] = 100;
        _receivers[0] = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
        // receivers[1] = address(0x731E7a35DDBB7d2b168D16824B371034f0DD0024);

        // Create a dummy plan for testing

        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_FIAT_PRICE,
            tokenAddress: address(0),
            amounts: _amounts,
            receivers: _receivers,
            contractAddress: address(0),
            feeController: IFeeController(address(protocolStandardFees)) //IFeeController(address(0))
        });
        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
            durationSecs: 86400,
            amount: 1,
            minAmount: 1,
            maxAmount: 1,
            proofRequired: false,
            nftAddress: address(nftExpirableCredits)
        });

        (uint256[] memory amounts, address[] memory receivers) =
            assetsRegistry.addFeesToPaymentsDistribution(priceConfig, creditsConfig);

        priceConfig.amounts = amounts;
        priceConfig.receivers = receivers;
        // Register the plan
        address feeReceiver = nvmConfig.getFeeReceiver();
        console2.log('Fee Receiver:', feeReceiver);
        console2.log(priceConfig.amounts[0]);
        console2.log(priceConfig.receivers[0]);
        console2.log(priceConfig.amounts[1]);
        console2.log(priceConfig.receivers[1]);

        uint256 planId = assetsRegistry.createPlan(priceConfig, creditsConfig);

        bool areFeesIncluded = assetsRegistry.areNeverminedFeesIncluded(planId);
        assertTrue(areFeesIncluded);
    }

    function test_areNeverminedFeesIncluded_feeReceiverIncludedButAmountTooHigh() public {
        // Setup NVM Fee Receiver
        vm.prank(governor);
        nvmConfig.setFeeReceiver(nvmFeeReceiver); // 10% fee

        uint256[] memory amounts = new uint256[](2);
        address[] memory receivers = new address[](2);

        // Set up receivers with nvmFeeReceiver but incorrect amount
        amounts[0] = 1000;
        amounts[1] = 200; // Too high fee amount (should be 100 for 10% of 1000)
        receivers[0] = address(1);
        receivers[1] = nvmFeeReceiver;

        // Create a dummy plan for testing
        IAsset.Plan memory plan = IAsset.Plan({
            owner: address(this),
            price: IAsset.PriceConfig({
                priceType: IAsset.PriceType.FIXED_PRICE,
                tokenAddress: address(0),
                amounts: amounts,
                receivers: receivers,
                contractAddress: address(0),
                feeController: IFeeController(address(0))
            }),
            credits: IAsset.CreditsConfig({
                creditsType: IAsset.CreditsType.FIXED,
                redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
                durationSecs: 0,
                amount: 100,
                minAmount: 1,
                maxAmount: 1,
                proofRequired: false,
                nftAddress: address(nftCredits)
            }),
            lastUpdated: block.timestamp
        });

        vm.expectPartialRevert(IAsset.NeverminedFeesNotIncluded.selector);
        assetsRegistry.createPlan(plan.price, plan.credits);
    }

    function test_setPlanFeeController() public {
        uint256 planId = _createPlan();

        // Set a custom fee controller
        vm.prank(governor);
        assetsRegistry.setPlanFeeController(planId, IFeeController(protocolStandardFees));

        // Verify the fee controller was set
        IAsset.Plan memory plan = assetsRegistry.getPlan(planId);
        assertEq(address(plan.price.feeController), address(protocolStandardFees));
    }

    function test_setPlanFeeController_revertIfNotGovernor() public {
        uint256 planId = _createPlan();

        // Try to set fee controller as non-governor
        address nonGovernor = makeAddr('nonGovernor');
        vm.prank(nonGovernor);
        vm.expectPartialRevert(IAccessManaged.AccessManagedUnauthorized.selector);
        assetsRegistry.setPlanFeeController(planId, IFeeController(protocolStandardFees));
    }

    function test_setPlanHooks() public {
        uint256 planId = _createPlan();

        // Create mock hooks
        IHook[] memory hooks = new IHook[](2);
        hooks[0] = IHook(makeAddr('hook1'));
        hooks[1] = IHook(makeAddr('hook2'));

        // Set hooks for the plan
        assetsRegistry.setPlanHooks(planId, hooks);

        // Verify hooks were set correctly
        IHook[] memory retrievedHooks = assetsRegistry.getPlanHooks(planId);
        assertEq(retrievedHooks.length, 2);
        assertEq(address(retrievedHooks[0]), address(hooks[0]));
        assertEq(address(retrievedHooks[1]), address(hooks[1]));
    }

    function test_setPlanHooks_revertIfNotOwner() public {
        uint256 planId = _createPlan();

        // Create mock hooks
        IHook[] memory hooks = new IHook[](1);
        hooks[0] = IHook(makeAddr('hook1'));

        // Try to set hooks as non-owner
        address nonOwner = makeAddr('nonOwner');
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(IAsset.NotPlanOwner.selector, planId, nonOwner, address(this)));
        assetsRegistry.setPlanHooks(planId, hooks);
    }

    function test_setPlanHooks_revertIfPlanNotFound() public {
        uint256 nonExistentPlanId = 999;

        // Create mock hooks
        IHook[] memory hooks = new IHook[](1);
        hooks[0] = IHook(makeAddr('hook1'));

        vm.expectRevert(abi.encodeWithSelector(IAsset.PlanNotFound.selector, nonExistentPlanId));
        assetsRegistry.setPlanHooks(nonExistentPlanId, hooks);
    }

    function test_replacePlansForAsset_PlansMustBeUnique_reverts() public {
        // Create two plans with different nonces to ensure they have different IDs
        uint256 planId1 = _createPlan(1);
        _createPlan(2);

        // Register an asset with the first plan
        bytes32 did = _registerAsset(planId1);

        // Create an array with duplicate plan IDs (planId1 appears twice)
        uint256[] memory duplicatePlans = new uint256[](2);
        duplicatePlans[0] = planId1;
        duplicatePlans[1] = planId1; // duplicate

        // Attempt to replace plans with duplicates - should revert
        vm.prank(address(this));
        vm.expectRevert(IAsset.PlansMustBeUnique.selector);
        assetsRegistry.replacePlansForAsset(did, duplicatePlans);
    }

    function test_replacePlansForAsset_PlansMustBeAscending_reverts() public {
        // Create two plans with different nonces to ensure they have different IDs
        uint256 planId1 = _createPlan(1);
        uint256 planId2 = _createPlan(2);

        // Register an asset with the first plan
        bytes32 did = _registerAsset(planId1);

        // Create an array with plans in descending order (planId2 > planId1, but we put planId2 first)
        uint256[] memory descendingPlans = new uint256[](2);
        descendingPlans[0] = planId2; // higher ID first
        descendingPlans[1] = planId1; // lower ID second

        // Attempt to replace plans with descending order - should revert
        vm.prank(address(this));
        vm.expectRevert(IAsset.PlansMustBeUnique.selector);
        assetsRegistry.replacePlansForAsset(did, descendingPlans);
    }
}
