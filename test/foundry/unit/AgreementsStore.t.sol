// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { AgreementsStore } from '../../../contracts/agreements/AgreementsStore.sol';
import { BaseTest } from '../common/BaseTest.sol';
import { AgreementsStoreV2 } from '../../../contracts/mock/AgreementsStoreV2.sol';
import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

contract AgreementsStoreTest is BaseTest {
  function setUp() public override {
    super.setUp();
  }

  function test_upgraderShouldBeAbleToUpgradeAfterDelay() public {
    string memory newVersion = '2.0.0';

    uint48 upgradeTime = uint48(block.timestamp + UPGRADE_DELAY);

    AgreementsStoreV2 agreementsStoreV2Impl = new AgreementsStoreV2();

    vm.prank(upgrader);
    accessManager.schedule(
      address(agreementsStore),
      abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(agreementsStoreV2Impl), bytes(''))),
      upgradeTime
    );

    vm.warp(upgradeTime);

    vm.prank(upgrader);
    accessManager.execute(
      address(agreementsStore),
      abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(agreementsStoreV2Impl), bytes('')))
    );

    AgreementsStoreV2 agreementsStoreV2 = AgreementsStoreV2(address(agreementsStore));

    vm.prank(governor);
    agreementsStoreV2.initializeV2(newVersion);

    assertEq(agreementsStoreV2.getVersion(), newVersion);
  }
}
