// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {AssetsRegistry} from '../../../contracts/AssetsRegistry.sol';
import {NVMConfig} from '../../../contracts/NVMConfig.sol';
import {IAsset} from '../../../contracts/interfaces/IAsset.sol';

import {INFT1155} from '../../../contracts/interfaces/INFT1155.sol';
import {INVMConfig} from '../../../contracts/interfaces/INVMConfig.sol';

import '../../../contracts/common/Roles.sol';
import {NFT1155CreditsV2} from '../../../contracts/mock/NFT1155CreditsV2.sol';
import {NFT1155Credits} from '../../../contracts/token/NFT1155Credits.sol';
import {BaseTest} from '../common/BaseTest.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {IAccessManaged} from '@openzeppelin/contracts/access/manager/IAccessManaged.sol';
import {Vm} from 'forge-std/Vm.sol';

contract NFT1155CreditsTest is BaseTest {
    Vm.Wallet private receiverWallet;
    address public receiver;
    address public unauthorized = makeAddr('unauthorized');
    // Using the CREDITS_MINTER_ROLE from BaseTest

    function setUp() public override {
        super.setUp();
        receiverWallet = vm.createWallet('receiver');
        receiver = receiverWallet.addr;
    }

    function test_balanceOf_randomPlan() public view {
        uint256 balance = nftCredits.balanceOf(owner, 1);
        assertEq(balance, 0);
    }

    function test_mint_noPlanRevert() public {
        vm.expectPartialRevert(IAsset.PlanNotFound.selector);
        nftCredits.mint(owner, 1, 1, '');
    }

    function test_minter_role_can_mint() public {
        _grantRole(CREDITS_MINTER_ROLE, address(this));

        uint256 planId = _createPlan();

        nftCredits.mint(receiver, planId, 1, '');
        uint256 balance = nftCredits.balanceOf(receiver, planId);
        assertEq(balance, 1);
    }

    function test_plan_owner_can_mint() public {
        uint256 planId = _createPlan();

        nftCredits.mint(receiver, planId, 2, '');
        uint256 balance = nftCredits.balanceOf(receiver, planId);
        assertEq(balance, 2);
    }

    function test_mint_unauthorized() public {
        uint256 planId = _createPlan();

        vm.prank(unauthorized);
        vm.expectPartialRevert(INFT1155.InvalidRole.selector);
        nftCredits.mint(receiver, planId, 1, '');
    }

    function test_mintBatch_correct() public {
        // Grant CREDITS_MINTER_ROLE to this contract
        _grantRole(CREDITS_MINTER_ROLE, address(this));

        // Create unique plans with different configurations
        uint256 planId1 = _createPlanWithAmount(100);
        uint256 planId2 = _createPlanWithAmount(200);

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

    // Helper function to create plans with different amounts
    function _createPlanWithAmount(uint256 amount) internal returns (uint256) {
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = amount;
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
            proofRequired: false,
            durationSecs: 0,
            amount: amount,
            minAmount: 1,
            maxAmount: 100
        });

        vm.prank(owner);
        assetsRegistry.createPlan(priceConfig, creditsConfig, address(nftCredits));
        return assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(nftCredits), address(this));
    }

    function test_mintBatch_unauthorized() public {
        // Create unique plans with different configurations
        uint256 planId1 = _createPlanWithAmount(300);
        uint256 planId2 = _createPlanWithAmount(400);

        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        ids[0] = planId1;
        ids[1] = planId2;
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(unauthorized);
        vm.expectPartialRevert(IAccessManaged.AccessManagedUnauthorized.selector);
        nftCredits.mintBatch(receiver, ids, amounts, '');
    }

    function test_burn_noPlanRevert() public {
        vm.expectPartialRevert(IAsset.PlanNotFound.selector);
        nftCredits.burn(owner, 1, 1, 0, '');
    }

    function test_burn_correct() public {
        _grantRole(CREDITS_MINTER_ROLE, address(this));
        _grantRole(CREDITS_BURNER_ROLE, address(this));

        uint256 planId = _createPlan();

        nftCredits.mint(receiver, planId, 5, '');
        nftCredits.burn(receiver, planId, 1, 0, '');
        uint256 balance = nftCredits.balanceOf(receiver, planId);
        assertEq(balance, 4);
    }

    function test_burn_unauthorized() public {
        _grantRole(CREDITS_MINTER_ROLE, address(this));

        uint256 planId = _createPlan();
        nftCredits.mint(receiver, planId, 5, '');

        vm.prank(unauthorized);
        vm.expectPartialRevert(INFT1155.InvalidRedemptionPermission.selector);
        nftCredits.burn(receiver, planId, 1, 0, '');
    }

    function test_burn_withSignature_required() public {
        // Create a plan that requires proof
        uint256 planId = _createPlanWithProofRequired(0);

        // Grant necessary roles
        _grantRole(CREDITS_MINTER_ROLE, address(this));
        _grantRole(CREDITS_BURNER_ROLE, address(this));

        // Mint some credits
        nftCredits.mint(receiver, planId, 5, '');

        // Get the next nonce for the keyspace
        uint256[] memory keyspaces = new uint256[](1);
        keyspaces[0] = 0;
        uint256[] memory nonces = nftCredits.nextNonce(receiver, keyspaces);
        uint256 nonce = nonces[0];

        // Create the proof data
        uint256[] memory planIds = new uint256[](1);
        planIds[0] = planId;
        INFT1155.CreditsBurnProofData memory proof =
            INFT1155.CreditsBurnProofData({keyspace: 0, nonce: nonce, planIds: planIds});

        // Sign the proof
        bytes32 digest = nftCredits.hashCreditsBurnProof(proof);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(receiverWallet, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Burn with valid signature
        nftCredits.burn(receiver, planId, 1, 0, signature);

        // Verify balance after burn
        uint256 balance = nftCredits.balanceOf(receiver, planId);
        assertEq(balance, 4);
    }

    function test_burn_withSignature_invalid() public {
        // Create a plan that requires proof
        uint256 planId = _createPlanWithProofRequired(0);

        // Grant necessary roles
        _grantRole(CREDITS_MINTER_ROLE, address(this));
        _grantRole(CREDITS_BURNER_ROLE, address(this));

        // Mint some credits
        nftCredits.mint(receiver, planId, 5, '');

        // Get the next nonce for the keyspace
        uint256[] memory keyspaces = new uint256[](1);
        keyspaces[0] = 0;
        uint256[] memory nonces = nftCredits.nextNonce(receiver, keyspaces);
        uint256 nonce = nonces[0];

        // Create the proof data
        uint256[] memory planIds = new uint256[](1);
        planIds[0] = planId;
        INFT1155.CreditsBurnProofData memory proof =
            INFT1155.CreditsBurnProofData({keyspace: 0, nonce: nonce, planIds: planIds});

        // Sign the proof with a different private key (not the receiver's)
        Vm.Wallet memory otherWallet = vm.createWallet('other');
        bytes32 digest = nftCredits.hashCreditsBurnProof(proof);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(otherWallet, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Try to burn with invalid signature
        vm.expectRevert(abi.encodeWithSelector(INFT1155.InvalidCreditsBurnProof.selector, otherWallet.addr, receiver));
        nftCredits.burn(receiver, planId, 1, 0, signature);
    }

    function test_burnBatch_correct() public {
        // Grant CREDITS_MINTER_ROLE to this contract
        _grantRole(CREDITS_MINTER_ROLE, address(this));

        // Grant CREDITS_BURNER_ROLE to this contract
        _grantRole(CREDITS_BURNER_ROLE, address(this));

        // Create unique plans with different configurations
        uint256 planId1 = _createPlanWithAmount(500);
        uint256 planId2 = _createPlanWithAmount(600);

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
        nftCredits.burnBatch(receiver, ids, burnAmounts, 0, '');

        uint256 balance1 = nftCredits.balanceOf(receiver, planId1);
        uint256 balance2 = nftCredits.balanceOf(receiver, planId2);

        assertEq(balance1, 99);
        assertEq(balance2, 199);
    }

    function test_burnBatch_unauthorized() public {
        // Grant CREDITS_MINTER_ROLE to this contract
        _grantRole(CREDITS_MINTER_ROLE, address(this));

        // Create unique plans with different configurations
        uint256 planId1 = _createPlanWithAmount(700);
        uint256 planId2 = _createPlanWithAmount(800);

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
        vm.expectPartialRevert(IAccessManaged.AccessManagedUnauthorized.selector);
        nftCredits.burnBatch(receiver, ids, burnAmounts, 0, '');
    }

    function test_burnBatch_withSignature_required() public {
        // Create plans that require proof
        uint256 planId1 = _createPlanWithProofRequired(0);
        uint256 planId2 = _createPlanWithProofRequired(1);

        // Grant necessary roles
        _grantRole(CREDITS_MINTER_ROLE, address(this));
        _grantRole(CREDITS_BURNER_ROLE, address(this));

        // Mint credits for both plans
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = planId1;
        ids[1] = planId2;
        amounts[0] = 100;
        amounts[1] = 200;
        nftCredits.mintBatch(receiver, ids, amounts, '');

        // Get the next nonce for the keyspace
        uint256[] memory keyspaces = new uint256[](1);
        keyspaces[0] = 0;
        uint256[] memory nonces = nftCredits.nextNonce(receiver, keyspaces);
        uint256 nonce = nonces[0];

        // Create the proof data
        uint256[] memory planIds = new uint256[](2);
        planIds[0] = planId1;
        planIds[1] = planId2;
        INFT1155.CreditsBurnProofData memory proof =
            INFT1155.CreditsBurnProofData({keyspace: 0, nonce: nonce, planIds: planIds});

        // Sign the proof
        bytes32 digest = nftCredits.hashCreditsBurnProof(proof);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(receiverWallet, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Burn batch with valid signature
        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 50;
        burnAmounts[1] = 75;
        nftCredits.burnBatch(receiver, ids, burnAmounts, 0, signature);

        // Verify balances after burn
        uint256 balance1 = nftCredits.balanceOf(receiver, planId1);
        uint256 balance2 = nftCredits.balanceOf(receiver, planId2);
        assertEq(balance1, 99);
        assertEq(balance2, 199);
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
