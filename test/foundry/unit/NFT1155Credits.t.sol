// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {AssetsRegistry} from '../../../contracts/AssetsRegistry.sol';
import {NVMConfig} from '../../../contracts/NVMConfig.sol';
import {IAsset} from '../../../contracts/interfaces/IAsset.sol';
import {INVMConfig} from '../../../contracts/interfaces/INVMConfig.sol';

import {NFT1155CreditsV2} from '../../../contracts/mock/NFT1155CreditsV2.sol';
import {NFT1155Credits} from '../../../contracts/token/NFT1155Credits.sol';
import {BaseTest} from '../common/BaseTest.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

contract NFT1155CreditsTest is BaseTest {
    address public receiver = makeAddr('receiver');
    address public unauthorized = makeAddr('unauthorized');
    // Using the CREDITS_MINTER_ROLE from BaseTest

    function setUp() public override {
        super.setUp();
    }

    function test_balanceOf_randomPlan() public view {
        uint256 balance = nftCredits.balanceOf(owner, 1);
        assertEq(balance, 0);
    }

    function test_mint_noPlanRevert() public {
        vm.expectPartialRevert(IAsset.PlanNotFound.selector);
        nftCredits.mint(owner, 1, 1, '');
    }

    function test_mint_correct() public {
        vm.prank(owner);
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(this));

        uint256 planId = _createPlan();

        nftCredits.mint(receiver, planId, 1, '');
        uint256 balance = nftCredits.balanceOf(receiver, planId);
        assertEq(balance, 1);
    }

    function test_mint_unauthorized() public {
        uint256 planId = _createPlan();
        
        vm.prank(unauthorized);
        vm.expectPartialRevert(INVMConfig.InvalidRole.selector);
        nftCredits.mint(receiver, planId, 1, '');
    }

    function test_mintBatch_correct() public {
        vm.prank(owner);
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(this));

        uint256 planId1 = _createPlan();
        uint256 planId2 = _createPlan();
        
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        
        ids[0] = planId1;
        ids[1] = planId2;
        amounts[0] = 100;
        amounts[1] = 200;
        
        nftCredits.mintBatch(receiver, ids, amounts, '');
        
        uint256 balance1 = nftCredits.balanceOf(receiver, planId1);
        uint256 balance2 = nftCredits.balanceOf(receiver, planId2);
        
        assertEq(balance1, 100);
        assertEq(balance2, 200);
    }
    
    function test_mintBatch_unauthorized() public {
        uint256 planId1 = _createPlan();
        uint256 planId2 = _createPlan();
        
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        
        ids[0] = planId1;
        ids[1] = planId2;
        amounts[0] = 100;
        amounts[1] = 200;
        
        vm.prank(unauthorized);
        vm.expectPartialRevert(INVMConfig.InvalidRole.selector);
        nftCredits.mintBatch(receiver, ids, amounts, '');
    }

    function test_burn_noPlanRevert() public {
        vm.expectPartialRevert(IAsset.PlanNotFound.selector);
        nftCredits.burn(owner, 1, 1);
    }

    function test_burn_correct() public {
        vm.startPrank(owner);
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(this));
        nvmConfig.grantRole(nftCredits.CREDITS_BURNER_ROLE(), address(this));
        vm.stopPrank();

        uint256 planId = _createPlan();

        nftCredits.mint(receiver, planId, 5, '');
        nftCredits.burn(receiver, planId, 1);
        uint256 balance = nftCredits.balanceOf(receiver, planId);
        assertEq(balance, 4);
    }
    
    function test_burn_unauthorized() public {
        vm.prank(owner);
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(this));

        uint256 planId = _createPlan();
        nftCredits.mint(receiver, planId, 5, '');
        
        vm.prank(unauthorized);
        vm.expectPartialRevert(INVMConfig.InvalidRole.selector);
        nftCredits.burn(receiver, planId, 1);
    }
    
    function test_burnBatch_correct() public {
        vm.startPrank(owner);
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(this));
        nvmConfig.grantRole(nftCredits.CREDITS_BURNER_ROLE(), address(this));
        vm.stopPrank();

        uint256 planId1 = _createPlan();
        uint256 planId2 = _createPlan();
        
        uint256[] memory ids = new uint256[](2);
        uint256[] memory mintAmounts = new uint256[](2);
        uint256[] memory burnAmounts = new uint256[](2);
        
        ids[0] = planId1;
        ids[1] = planId2;
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        burnAmounts[0] = 50;
        burnAmounts[1] = 75;
        
        nftCredits.mintBatch(receiver, ids, mintAmounts, '');
        nftCredits.burnBatch(receiver, ids, burnAmounts);
        
        uint256 balance1 = nftCredits.balanceOf(receiver, planId1);
        uint256 balance2 = nftCredits.balanceOf(receiver, planId2);
        
        assertEq(balance1, 50);
        assertEq(balance2, 125);
    }
    
    function test_burnBatch_unauthorized() public {
        vm.prank(owner);
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(this));

        uint256 planId1 = _createPlan();
        uint256 planId2 = _createPlan();
        
        uint256[] memory ids = new uint256[](2);
        uint256[] memory mintAmounts = new uint256[](2);
        uint256[] memory burnAmounts = new uint256[](2);
        
        ids[0] = planId1;
        ids[1] = planId2;
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        burnAmounts[0] = 50;
        burnAmounts[1] = 75;
        
        nftCredits.mintBatch(receiver, ids, mintAmounts, '');
        
        vm.prank(unauthorized);
        vm.expectPartialRevert(INVMConfig.InvalidRole.selector);
        nftCredits.burnBatch(receiver, ids, burnAmounts);
    }

    function test_upgraderShouldBeAbleToUpgradeAfterDelay() public {
        string memory newVersion = '2.0.0';

        uint48 upgradeTime = uint48(block.timestamp + UPGRADE_DELAY);

        NFT1155CreditsV2 nft1155CreditsV2Impl = new NFT1155CreditsV2();

        vm.prank(upgrader);
        accessManager.schedule(
            address(nftCredits),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(nft1155CreditsV2Impl), bytes(''))),
            upgradeTime
        );

        vm.warp(upgradeTime);

        vm.prank(upgrader);
        accessManager.execute(
            address(nftCredits),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(nft1155CreditsV2Impl), bytes('')))
        );

        NFT1155CreditsV2 nft1155CreditsV2 = NFT1155CreditsV2(address(nftCredits));

        vm.prank(governor);
        nft1155CreditsV2.initializeV2(newVersion);

        assertEq(nft1155CreditsV2.getVersion(), newVersion);
    }
}
