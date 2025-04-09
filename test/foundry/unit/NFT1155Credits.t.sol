// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { NVMConfig } from '../../../contracts/NVMConfig.sol';
import { AssetsRegistry } from '../../../contracts/AssetsRegistry.sol';
import { IAsset } from '../../../contracts/interfaces/IAsset.sol';
import { NFT1155Credits } from '../../../contracts/token/NFT1155Credits.sol';
import { BaseTest } from '../common/BaseTest.sol';
import { NFT1155CreditsV2 } from '../../../contracts/mock/NFT1155CreditsV2.sol';
import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

contract NFT1155CreditsTest is BaseTest {
  address public receiver = makeAddr('receiver');

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

  function _createPlan() internal returns (uint256) {
    uint256[] memory _amounts = new uint256[](1);
    _amounts[0] = 100;
    address[] memory _receivers = new address[](1);
    _receivers[0] = owner;

    (uint256[] memory amounts, address[] memory receivers) = assetsRegistry
      .addFeesToPaymentsDistribution(_amounts, _receivers);
    IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
      priceType: IAsset.PriceType.FIXED_PRICE,
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
      minAmount: 1,
      maxAmount: 1
    });

    assetsRegistry.createPlan(priceConfig, creditsConfig, address(nftCredits));
    return
      assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(nftCredits), address(this));
  }
}
