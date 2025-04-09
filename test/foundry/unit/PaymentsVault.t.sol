// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { PaymentsVault } from '../../../contracts/PaymentsVault.sol';
import { BaseTest } from '../common/BaseTest.sol';
import { PaymentsVaultV2 } from '../../../contracts/mock/PaymentsVaultV2.sol';
import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

contract PaymentsVaultTest is BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function test_upgraderShouldBeAbleToUpgradeAfterDelay() public {
    string memory newVersion = '2.0.0';

    uint48 upgradeTime = uint48(block.timestamp + UPGRADE_DELAY);

    PaymentsVaultV2 paymentsVaultV2Impl = new PaymentsVaultV2();

    vm.prank(upgrader);
    accessManager.schedule(
      address(paymentsVault),
      abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(paymentsVaultV2Impl), bytes(''))),
      upgradeTime
    );

    vm.warp(upgradeTime);

    vm.prank(upgrader);
    accessManager.execute(
      address(paymentsVault),
      abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(paymentsVaultV2Impl), bytes('')))
    );

    PaymentsVaultV2 paymentsVaultV2 = PaymentsVaultV2(payable(address(paymentsVault)));

    vm.prank(governor);
    paymentsVaultV2.initializeV2(newVersion);

    assertEq(paymentsVaultV2.getVersion(), newVersion);
  }
}
