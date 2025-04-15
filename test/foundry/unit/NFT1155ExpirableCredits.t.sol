// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {AssetsRegistry} from '../../../contracts/AssetsRegistry.sol';
import {NVMConfig} from '../../../contracts/NVMConfig.sol';
import {IAsset} from '../../../contracts/interfaces/IAsset.sol';
import {INVMConfig} from '../../../contracts/interfaces/INVMConfig.sol';

import {NFT1155ExpirableCreditsV2} from '../../../contracts/mock/NFT1155ExpirableCreditsV2.sol';
import {NFT1155ExpirableCredits} from '../../../contracts/token/NFT1155ExpirableCredits.sol';
import {BaseTest} from '../common/BaseTest.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

contract NFT1155ExpirableCreditsTest is BaseTest {
    address public receiver = makeAddr('receiver');
    address public unauthorized = makeAddr('unauthorized');
    // Using the CREDITS_MINTER_ROLE from BaseTest
    uint256 public planId;

    function setUp() public override {
        super.setUp();
        
        // Create an expirable credits plan for testing
        planId = _createExpirablePlan();
    }
    
    function _createExpirablePlan() internal returns (uint256) {
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 100;
        address[] memory _receivers = new address[](1);
        _receivers[0] = owner;
        
        (uint256[] memory amounts, address[] memory receivers) =
            assetsRegistry.addFeesToPaymentsDistribution(_amounts, _receivers);
            
        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(0),
            amounts: amounts,
            receivers: receivers,
            contractAddress: address(0)
        });
        
        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.EXPIRABLE,
            redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
            durationSecs: 10,
            amount: 1,
            minAmount: 1,
            maxAmount: 1
        });
        
        vm.prank(owner);
        assetsRegistry.createPlan(priceConfig, creditsConfig, address(nftExpirableCredits));
        return assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(nftExpirableCredits), owner);
    }
    
    // Using _createPlanWithConfig from BaseTest instead of a custom function

    function test_balanceOf_randomPlan() public view {
        uint256 balance = nftExpirableCredits.balanceOf(owner, 1);
        assertEq(balance, 0);
    }

    function test_mint_noPlanRevert() public {
        vm.expectPartialRevert(IAsset.PlanNotFound.selector);
        nftExpirableCredits.mint(owner, 999, 1, '');
    }

    function test_mint_correct() public {
        vm.prank(owner);
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(this));

        nftExpirableCredits.mint(receiver, planId, 1, '');
        uint256 balance = nftExpirableCredits.balanceOf(receiver, planId);
        assertEq(balance, 1);
    }

    function test_mint_unauthorized() public {
        vm.prank(unauthorized);
        vm.expectPartialRevert(INVMConfig.InvalidRole.selector);
        nftExpirableCredits.mint(receiver, planId, 1, '');
    }

    function test_mintWithExpirationTime() public {
        vm.prank(owner);
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(this));

        // Mint with 10 seconds expiration
        nftExpirableCredits.mintWithExpirationTime(receiver, planId, 1, 10, '');
        
        // Check initial balance
        uint256 initialBalance = nftExpirableCredits.balanceOf(receiver, planId);
        assertEq(initialBalance, 1);
        
        // Advance time by 15 seconds (past expiration)
        vm.warp(block.timestamp + 15);
        
        // Check balance after expiration
        uint256 finalBalance = nftExpirableCredits.balanceOf(receiver, planId);
        assertEq(finalBalance, 0);
    }

    function test_mintWithoutExpiration() public {
        vm.prank(owner);
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(this));

        // Mint with no expiration (0 seconds)
        nftExpirableCredits.mintWithExpirationTime(receiver, planId, 1, 0, '');
        
        // Check initial balance
        uint256 initialBalance = nftExpirableCredits.balanceOf(receiver, planId);
        assertEq(initialBalance, 1);
        
        // Advance time by 100 seconds
        vm.warp(block.timestamp + 100);
        
        // Check balance after time advance - should still be the same
        uint256 finalBalance = nftExpirableCredits.balanceOf(receiver, planId);
        assertEq(finalBalance, 1);
    }

    function test_mixedExpirationCredits() public {
        vm.prank(owner);
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(this));

        // Mint expirable credits (50 tokens with 20 seconds expiration)
        nftExpirableCredits.mintWithExpirationTime(receiver, planId, 50, 20, '');
        
        // Mint permanent credits (100 tokens with no expiration)
        nftExpirableCredits.mintWithExpirationTime(receiver, planId, 100, 0, '');
        
        // Check initial balance (should be sum of both)
        uint256 initialBalance = nftExpirableCredits.balanceOf(receiver, planId);
        assertEq(initialBalance, 150);
        
        // Advance time by 30 seconds (past expiration of first batch)
        vm.warp(block.timestamp + 30);
        
        // Check balance after partial expiration
        uint256 finalBalance = nftExpirableCredits.balanceOf(receiver, planId);
        assertEq(finalBalance, 100);
    }

    function test_multipleExpirationTimes() public {
        vm.prank(owner);
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(this));

        // Mint with different expiration times
        nftExpirableCredits.mintWithExpirationTime(receiver, planId, 50, 10, '');  // 10 seconds
        nftExpirableCredits.mintWithExpirationTime(receiver, planId, 75, 30, '');  // 30 seconds
        nftExpirableCredits.mintWithExpirationTime(receiver, planId, 100, 60, ''); // 60 seconds
        
        // Check initial balance
        uint256 initialBalance = nftExpirableCredits.balanceOf(receiver, planId);
        assertEq(initialBalance, 225);
        
        // Advance time by 15 seconds (past first expiration)
        vm.warp(block.timestamp + 15);
        uint256 balanceAfterFirstExpiration = nftExpirableCredits.balanceOf(receiver, planId);
        assertEq(balanceAfterFirstExpiration, 175);
        
        // Advance time by another 20 seconds (past second expiration)
        vm.warp(block.timestamp + 20);
        uint256 balanceAfterSecondExpiration = nftExpirableCredits.balanceOf(receiver, planId);
        assertEq(balanceAfterSecondExpiration, 100);
        
        // Advance time by another 30 seconds (past all expirations)
        vm.warp(block.timestamp + 30);
        uint256 finalBalance = nftExpirableCredits.balanceOf(receiver, planId);
        assertEq(finalBalance, 0);
    }

    function test_burn_correct() public {
        vm.startPrank(owner);
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(this));
        nvmConfig.grantRole(nftExpirableCredits.CREDITS_BURNER_ROLE(), address(this));
        vm.stopPrank();

        nftExpirableCredits.mintWithExpirationTime(receiver, planId, 5, 0, '');
        nftExpirableCredits.burn(receiver, planId, 1);
        uint256 balance = nftExpirableCredits.balanceOf(receiver, planId);
        assertEq(balance, 4);
    }
    
    function test_burn_unauthorized() public {
        vm.prank(owner);
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(this));

        nftExpirableCredits.mintWithExpirationTime(receiver, planId, 5, 0, '');
        
        vm.prank(unauthorized);
        vm.expectPartialRevert(INVMConfig.InvalidRole.selector);
        nftExpirableCredits.burn(receiver, planId, 1);
    }

    function test_upgraderShouldBeAbleToUpgradeAfterDelay() public {
        string memory newVersion = '2.0.0';

        uint48 upgradeTime = uint48(block.timestamp + UPGRADE_DELAY);

        NFT1155ExpirableCreditsV2 nft1155ExpirableCreditsV2Impl = new NFT1155ExpirableCreditsV2();

        vm.prank(upgrader);
        accessManager.schedule(
            address(nftExpirableCredits),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(nft1155ExpirableCreditsV2Impl), bytes(''))),
            upgradeTime
        );

        vm.warp(upgradeTime);

        vm.prank(upgrader);
        accessManager.execute(
            address(nftExpirableCredits),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(nft1155ExpirableCreditsV2Impl), bytes('')))
        );

        NFT1155ExpirableCreditsV2 nft1155ExpirableCreditsV2 = NFT1155ExpirableCreditsV2(address(nftExpirableCredits));

        vm.prank(governor);
        nft1155ExpirableCreditsV2.initializeV2(newVersion);

        assertEq(nft1155ExpirableCreditsV2.getVersion(), newVersion);
    }
}
