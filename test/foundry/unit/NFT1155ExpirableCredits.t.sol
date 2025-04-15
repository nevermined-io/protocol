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
    address public minter;
    address public burner;
    address public receiver;
    address public unauthorized;
    bytes32 public CREDITS_BURNER_ROLE;
    uint256 public planId;
    uint256 public planId2;

    function setUp() public override {
        super.setUp();
        
        // Create addresses for testing
        minter = makeAddr('minter');
        burner = makeAddr('burner');
        receiver = makeAddr('receiver');
        unauthorized = makeAddr('unauthorized');
        
        // Get role constants from the contract
        CREDITS_BURNER_ROLE = nftExpirableCredits.CREDITS_BURNER_ROLE();
        
        // Grant necessary roles for testing
        vm.startPrank(owner);
        nvmConfig.grantRole(nftExpirableCredits.CREDITS_MINTER_ROLE(), address(this));
        nvmConfig.grantRole(nftExpirableCredits.CREDITS_MINTER_ROLE(), minter);
        nvmConfig.grantRole(nftExpirableCredits.CREDITS_BURNER_ROLE(), address(this));
        nvmConfig.grantRole(nftExpirableCredits.CREDITS_BURNER_ROLE(), burner);
        vm.stopPrank();
        
        // Create expirable credits plans for testing
        planId = _createExpirablePlan(1, 10);
        planId2 = _createExpirablePlan(200, 10);
    }
    
    function _createExpirablePlan(uint256 amount, uint256 durationSecs) internal returns (uint256) {
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
            durationSecs: durationSecs,
            amount: amount,
            minAmount: 1,
            maxAmount: amount
        });
        
        vm.prank(owner);
        assetsRegistry.createPlan(priceConfig, creditsConfig, address(nftExpirableCredits));
        return assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(nftExpirableCredits), owner);
    }

    function test_balanceOf_randomPlan() public view {
        uint256 balance = nftExpirableCredits.balanceOf(owner, 999);
        assertEq(balance, 0);
    }

    function test_mint_noPlanRevert() public {
        vm.prank(minter);
        vm.expectPartialRevert(IAsset.PlanNotFound.selector);
        nftExpirableCredits.mint(owner, 999, 1, '');
    }

    function test_mint_correct() public {
        vm.prank(minter);
        nftExpirableCredits.mint(receiver, planId, 1, '');
        
        uint256 balance = nftExpirableCredits.balanceOf(receiver, planId);
        assertEq(balance, 1);
    }

    function test_mint_unauthorized() public {
        vm.prank(unauthorized);
        vm.expectPartialRevert(INVMConfig.InvalidRole.selector);
        nftExpirableCredits.mint(receiver, planId, 1, '');
    }

    function test_mintWithExpiration() public {
        // Mint with 10 seconds expiration
        vm.prank(minter);
        nftExpirableCredits.mint(receiver, planId, 1, 10, '');
        
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
        // Mint with no expiration (0 seconds)
        vm.prank(minter);
        nftExpirableCredits.mint(receiver, planId, 1, 0, '');
        
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
        vm.startPrank(minter);
        
        // Mint expirable credits (50 tokens with 20 seconds expiration)
        nftExpirableCredits.mint(receiver, planId, 50, 20, '');
        
        // Mint permanent credits (100 tokens with no expiration)
        nftExpirableCredits.mint(receiver, planId, 100, 0, '');
        
        vm.stopPrank();
        
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
        vm.startPrank(minter);
        
        // Mint with different expiration times
        nftExpirableCredits.mint(receiver, planId, 50, 10, '');  // 10 seconds
        nftExpirableCredits.mint(receiver, planId, 75, 30, '');  // 30 seconds
        nftExpirableCredits.mint(receiver, planId, 100, 60, ''); // 60 seconds
        
        vm.stopPrank();
        
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
        // First mint some credits
        vm.prank(minter);
        nftExpirableCredits.mint(receiver, planId, 5, 0, '');
        
        // Then burn some as authorized burner
        vm.prank(burner);
        nftExpirableCredits.burn(receiver, planId, 1);
        
        // Check balance after burn
        uint256 balance = nftExpirableCredits.balanceOf(receiver, planId);
        assertEq(balance, 4);
    }
    
    function test_burn_unauthorized() public {
        // First mint some credits
        vm.prank(minter);
        nftExpirableCredits.mint(receiver, planId, 5, 0, '');
        
        // Try to burn as unauthorized account
        vm.prank(unauthorized);
        vm.expectPartialRevert(INVMConfig.InvalidRole.selector);
        nftExpirableCredits.burn(receiver, planId, 1);
    }

    function test_burnBatch() public {
        // Mint credits for both plans
        vm.startPrank(minter);
        nftExpirableCredits.mint(receiver, planId, 100, 0, '');
        nftExpirableCredits.mint(receiver, planId2, 200, 0, '');
        vm.stopPrank();
        
        // Prepare batch burn data
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = planId;
        ids[1] = planId2;
        amounts[0] = 50;
        amounts[1] = 75;
        
        // Burn batch as authorized burner
        vm.prank(burner);
        nftExpirableCredits.burnBatch(receiver, ids, amounts);
        
        // Check balances after burn
        uint256 balance1 = nftExpirableCredits.balanceOf(receiver, planId);
        uint256 balance2 = nftExpirableCredits.balanceOf(receiver, planId2);
        
        assertEq(balance1, 50);
        assertEq(balance2, 125);
    }
    
    function test_burnBatch_unauthorized() public {
        // Mint credits for both plans
        vm.startPrank(minter);
        nftExpirableCredits.mint(receiver, planId, 100, 0, '');
        nftExpirableCredits.mint(receiver, planId2, 200, 0, '');
        vm.stopPrank();
        
        // Prepare batch burn data
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = planId;
        ids[1] = planId2;
        amounts[0] = 50;
        amounts[1] = 75;
        
        // Try to burn batch as unauthorized account
        vm.prank(unauthorized);
        vm.expectPartialRevert(INVMConfig.InvalidRole.selector);
        nftExpirableCredits.burnBatch(receiver, ids, amounts);
    }

    function test_mintBatch() public {
        // Prepare batch mint data
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory durations = new uint256[](2);
        
        ids[0] = planId;
        ids[1] = planId2;
        amounts[0] = 50;
        amounts[1] = 75;
        durations[0] = 10;
        durations[1] = 20;
        
        // Mint batch as authorized minter
        vm.prank(minter);
        nftExpirableCredits.mintBatch(receiver, ids, amounts, durations, '');
        
        // Check balances after mint
        uint256 balance1 = nftExpirableCredits.balanceOf(receiver, planId);
        uint256 balance2 = nftExpirableCredits.balanceOf(receiver, planId2);
        
        assertEq(balance1, 50);
        assertEq(balance2, 75);
        
        // Advance time by 15 seconds (past first expiration)
        vm.warp(block.timestamp + 15);
        
        // Check balances after first expiration
        balance1 = nftExpirableCredits.balanceOf(receiver, planId);
        balance2 = nftExpirableCredits.balanceOf(receiver, planId2);
        
        assertEq(balance1, 0);
        assertEq(balance2, 75);
        
        // Advance time by 10 more seconds (past second expiration)
        vm.warp(block.timestamp + 10);
        
        // Check balances after second expiration
        balance1 = nftExpirableCredits.balanceOf(receiver, planId);
        balance2 = nftExpirableCredits.balanceOf(receiver, planId2);
        
        assertEq(balance1, 0);
        assertEq(balance2, 0);
    }
    
    function test_mintBatch_unauthorized() public {
        // Prepare batch mint data
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory durations = new uint256[](2);
        
        ids[0] = planId;
        ids[1] = planId2;
        amounts[0] = 50;
        amounts[1] = 75;
        durations[0] = 10;
        durations[1] = 20;
        
        // Try to mint batch as unauthorized account
        vm.prank(unauthorized);
        vm.expectPartialRevert(INVMConfig.InvalidRole.selector);
        nftExpirableCredits.mintBatch(receiver, ids, amounts, durations, '');
    }

    function test_upgraderShouldBeAbleToUpgradeAfterDelay() public {
        string memory newVersion = '2.0.0';

        // Grant upgrade permissions to NFT1155ExpirableCredits
        vm.prank(owner);
        accessManager.setTargetFunctionRole(
            address(nftExpirableCredits), 
            toArray(UUPSUpgradeable.upgradeToAndCall.selector), 
            UPGRADE_ROLE
        );

        uint48 upgradeTime = uint48(block.timestamp + UPGRADE_DELAY);

        NFT1155ExpirableCreditsV2 nft1155ExpirableCreditsV2Impl = new NFT1155ExpirableCreditsV2();

        // Schedule the upgrade
        vm.prank(upgrader);
        accessManager.schedule(
            address(nftExpirableCredits),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(nft1155ExpirableCreditsV2Impl), bytes(''))),
            upgradeTime
        );

        // Advance time to the upgrade time
        vm.warp(upgradeTime);

        // Execute the upgrade
        vm.prank(upgrader);
        accessManager.execute(
            address(nftExpirableCredits),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(nft1155ExpirableCreditsV2Impl), bytes('')))
        );

        // Cast to V2 to access new functions
        NFT1155ExpirableCreditsV2 nft1155ExpirableCreditsV2 = NFT1155ExpirableCreditsV2(address(nftExpirableCredits));

        // Initialize V2 with the new version
        vm.prank(governor);
        nft1155ExpirableCreditsV2.initializeV2(newVersion);

        // Verify the version was set correctly
        assertEq(nft1155ExpirableCreditsV2.getVersion(), newVersion);
    }
}
