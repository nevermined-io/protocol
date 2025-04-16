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
    bytes32 private assetDid;
    uint256 private planId;
    address private newOwner;

    function setUp() public override {
        super.setUp();
        
        // Setup a new owner address for testing transfers
        newOwner = makeAddr("newOwner");
        
        // Register a test asset and plan for transfer tests
        bytes32 didSeed = keccak256("test-asset");
        string memory url = "https://example.com/metadata";
        
        // Create a plan
        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(0),
            amounts: new uint256[](1),
            receivers: new address[](1),
            contractAddress: address(0)
        });
        priceConfig.amounts[0] = 1 ether;
        priceConfig.receivers[0] = address(this);
        
        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_OWNER,
            durationSecs: 0,
            amount: 1,
            minAmount: 1,
            maxAmount: 1
        });
        
        vm.prank(address(this));
        assetsRegistry.createPlan(priceConfig, creditsConfig, address(0));
        planId = assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(0), address(this));
        
        // Register the asset with the plan
        uint256[] memory plans = new uint256[](1);
        plans[0] = planId;
        
        vm.prank(address(this));
        assetsRegistry.register(didSeed, url, plans);
        assetDid = assetsRegistry.hashDID(didSeed, address(this));
    }

    function test_transferAssetOwnership() public {
        // Verify initial owner
        IAsset.DIDAsset memory asset = assetsRegistry.getAsset(assetDid);
        assertEq(asset.owner, address(this));
        
        // Transfer ownership
        vm.prank(address(this));
        assetsRegistry.transferAssetOwnership(assetDid, newOwner);
        
        // Verify new owner
        asset = assetsRegistry.getAsset(assetDid);
        assertEq(asset.owner, newOwner);
    }
    
    function test_transferAssetOwnership_revertIfNotOwner() public {
        // Try to transfer ownership from non-owner account
        address nonOwner = makeAddr("nonOwner");
        
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(IAsset.NotAssetOwner.selector, assetDid, nonOwner, address(this)));
        assetsRegistry.transferAssetOwnership(assetDid, newOwner);
    }
    
    function test_transferAssetOwnership_revertIfAssetNotFound() public {
        // Try to transfer ownership of non-existent asset
        bytes32 nonExistentDid = keccak256("non-existent-asset");
        
        vm.prank(address(this));
        vm.expectRevert(abi.encodeWithSelector(IAsset.AssetNotFound.selector, nonExistentDid));
        assetsRegistry.transferAssetOwnership(nonExistentDid, newOwner);
    }
    
    function test_transferPlanOwnership() public {
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
        address nonOwner = makeAddr("nonOwner");
        
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(IAsset.NotPlanOwner.selector, planId, nonOwner, address(this)));
        assetsRegistry.transferPlanOwnership(planId, newOwner);
    }
    
    function test_transferPlanOwnership_revertIfPlanNotFound() public {
        // Try to transfer ownership of non-existent plan
        uint256 nonExistentPlanId = uint256(keccak256("non-existent-plan"));
        
        vm.prank(address(this));
        vm.expectRevert(abi.encodeWithSelector(IAsset.PlanNotFound.selector, nonExistentPlanId));
        assetsRegistry.transferPlanOwnership(nonExistentPlanId, newOwner);
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
