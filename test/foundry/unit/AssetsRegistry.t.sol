// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {AssetsRegistry} from '../../../contracts/AssetsRegistry.sol';
import {IAsset} from '../../../contracts/interfaces/IAsset.sol';
import {INVMConfig} from '../../../contracts/interfaces/INVMConfig.sol';
import {console2} from 'forge-std/console2.sol';

import {AssetsRegistryV2} from '../../../contracts/mock/AssetsRegistryV2.sol';
import {BaseTest} from '../common/BaseTest.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

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

        (uint256[] memory amounts, address[] memory receivers) =
            assetsRegistry.addFeesToPaymentsDistribution(_amounts, _receivers);
        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_FIAT_PRICE,
            tokenAddress: address(0),
            amounts: amounts,
            receivers: receivers,
            contractAddress: address(0)
        });
        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
            durationSecs: 0,
            amount: 100,
            proofRequired: false,
            minAmount: 1,
            maxAmount: 1
        });

        address nftAddress = address(assetsRegistry);
        vm.expectPartialRevert(IAsset.InvalidNFTAddress.selector);
        assetsRegistry.createPlan(priceConfig, creditsConfig, nftAddress);
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
            contractAddress: address(0)
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
            proofRequired: false
        });

        uint256 planId = assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(0), owner);
        assertTrue(planId > 0);
    }

    function test_getNonExistentPlan() public view {
        uint256 planId = 1;
        IAsset.Plan memory plan = assetsRegistry.getPlan(planId);
        assertEq(plan.lastUpdated, 0);
    }

    function test_addFeesToPaymentsDistribution() public view {
        uint256[] memory amounts = new uint256[](2);
        address[] memory receivers = new address[](2);

        amounts[0] = 1000;
        amounts[1] = 2000;
        receivers[0] = address(0x04005BBD24EC13D5920aD8845C55496A4C24c466);
        receivers[1] = address(0x9Aa6E515c64fC46FC8B20bA1Ca7f9B26ff404548);

        (uint256[] memory newAmounts, address[] memory newReceivers) =
            assetsRegistry.addFeesToPaymentsDistribution(amounts, receivers);

        bool areFeesIncluded = assetsRegistry.areNeverminedFeesIncluded(newAmounts, newReceivers);
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
}
