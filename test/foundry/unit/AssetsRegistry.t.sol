// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {AssetsRegistry} from '../../../contracts/AssetsRegistry.sol';
import {IAsset} from '../../../contracts/interfaces/IAsset.sol';

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

    function test_registerAsset() public {
        // Create a valid plan first
        uint256 planId = _createPlan();
        
        uint256[] memory planIds = new uint256[](1);
        planIds[0] = planId;
        
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit IAsset.AssetRegistered(testDid, owner);
        
        assetsRegistry.register('test-did', URL, planIds);
        
        IAsset.DIDAsset memory asset = assetsRegistry.getAsset(testDid);
        assertTrue(asset.lastUpdated > 0);
    }

    function test_cannotRegisterAssetWithoutPlans() public {
        uint256[] memory emptyPlans = new uint256[](0);
        
        vm.prank(owner);
        vm.expectPartialRevert(IAsset.NotPlansAttached.selector);
        
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
            maxAmount: 1
        });
        
        uint256 planId = assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(0), owner);
        assertTrue(planId > 0);
    }

    function test_getNonExistentPlan() public view {
        uint256 planId = 1;
        IAsset.Plan memory plan = assetsRegistry.getPlan(planId);
        assertEq(plan.lastUpdated, 0);
    }

    function test_cannotRegisterPlanWithoutFeesIncluded() public {
        // Create a price config without Nevermined fees
        uint256[] memory amounts = new uint256[](2);
        address[] memory receivers = new address[](2);
        
        amounts[0] = 1000;
        amounts[1] = 2000;
        receivers[0] = address(0x04005BBD24EC13D5920aD8845C55496A4C24c466);
        receivers[1] = address(0x9Aa6E515c64fC46FC8B20bA1Ca7f9B26ff404548);
        
        // Verify fees are not included
        bool areFeesIncluded = assetsRegistry.areNeverminedFeesIncluded(amounts, receivers);
        assertFalse(areFeesIncluded);
        
        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(0),
            amounts: amounts,
            receivers: receivers,
            contractAddress: address(0)
        });
        
        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_PLAN_ROLE,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 1
        });
        
        vm.prank(owner);
        vm.expectPartialRevert(IAsset.NeverminedFeesNotIncluded.selector);
        
        assetsRegistry.createPlan(priceConfig, creditsConfig, address(0));
    }

    function test_addFeesToPaymentsDistribution() public view {
        uint256[] memory amounts = new uint256[](2);
        address[] memory receivers = new address[](2);
        
        amounts[0] = 1000;
        amounts[1] = 2000;
        receivers[0] = address(0x04005BBD24EC13D5920aD8845C55496A4C24c466);
        receivers[1] = address(0x9Aa6E515c64fC46FC8B20bA1Ca7f9B26ff404548);
        
        (uint256[] memory newAmounts, address[] memory newReceivers) = assetsRegistry.addFeesToPaymentsDistribution(amounts, receivers);
        
        bool areFeesIncluded = assetsRegistry.areNeverminedFeesIncluded(newAmounts, newReceivers);
        assertTrue(areFeesIncluded);
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
