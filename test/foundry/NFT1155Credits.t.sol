// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { Test, console } from 'forge-std/Test.sol';
import { NVMConfig } from '../../contracts/NVMConfig.sol';
import { AssetsRegistry } from '../../contracts/AssetsRegistry.sol';
import { IAsset } from '../../contracts/interfaces/IAsset.sol';
import { NFT1155Credits } from '../../contracts/token/NFT1155Credits.sol';
import { NFT1155Base } from '../../contracts/token/NFT1155Base.sol';

contract NFT1155CreditsTest is Test {
  NVMConfig public nvmConfig;
  AssetsRegistry public assetsRegistry;
  NFT1155Credits public nft1155;

  address public owner;
  address public receiver;

  function setUp() public {
    nvmConfig = new NVMConfig();
    owner = address(this);
    receiver = address(1);
    nvmConfig.initialize(owner, address(0x1), owner); // TODO: add authority
    nvmConfig.setNetworkFees(100, owner);

    assetsRegistry = new AssetsRegistry();
    assetsRegistry.initialize(address(nvmConfig), address(0x1)); // TODO: add authority

    nft1155 = new NFT1155Credits();
    nft1155.initialize(
      address(nvmConfig),
      address(0x1),
      address(assetsRegistry),
      'NFT1155Credits',
      'NFT1155Credits'
    ); // TODO: add authority
  }

  function test_balanceOf_randomPlan() public view {
    uint256 balance = nft1155.balanceOf(owner, 1);
    assertEq(balance, 0);
  }

  function test_mint_noPlanRevert() public {
    vm.expectPartialRevert(IAsset.PlanNotFound.selector);
    nft1155.mint(owner, 1, 1, '');
  }

  function test_mint_correct() public {
    nvmConfig.grantRole(nft1155.CREDITS_MINTER_ROLE(), address(this));

    uint256 planId = _createPlan();

    nft1155.mint(receiver, planId, 1, '');
    uint256 balance = nft1155.balanceOf(receiver, planId);
    assertEq(balance, 1);
  }

  function test_burn_noPlanRevert() public {
    vm.expectPartialRevert(IAsset.PlanNotFound.selector);
    nft1155.burn(owner, 1, 1);
  }

  function test_burn_correct() public {
    nvmConfig.grantRole(nft1155.CREDITS_MINTER_ROLE(), address(this));
    nvmConfig.grantRole(nft1155.CREDITS_BURNER_ROLE(), address(this));

    uint256 planId = _createPlan();

    nft1155.mint(receiver, planId, 5, '');
    nft1155.burn(receiver, planId, 1);
    uint256 balance = nft1155.balanceOf(receiver, planId);
    assertEq(balance, 4);
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

    assetsRegistry.createPlan(priceConfig, creditsConfig, address(nft1155));
    return assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(nft1155), address(this));
  }
}
