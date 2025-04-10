// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {NVMConfig} from '../../../contracts/NVMConfig.sol';

import {NVMConfigV2} from '../../../contracts/mock/NVMConfigV2.sol';
import {BaseTest} from '../common/BaseTest.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/AccessManager.sol';

contract NVMConfigTest is BaseTest {
    function setUp() public override {
        super.setUp();

        vm.prank(governor);
        nvmConfig.setNetworkFees(100, owner);
    }

    function test_upgraderShouldBeAbleToUpgradeAfterDelay() public {
        string memory newVersion = '2.0.0';

        uint48 upgradeTime = uint48(block.timestamp + UPGRADE_DELAY);

        NVMConfigV2 nvmConfigV2Impl = new NVMConfigV2();

        vm.prank(upgrader);
        accessManager.schedule(
            address(nvmConfig),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(nvmConfigV2Impl), bytes(''))),
            upgradeTime
        );

        vm.warp(upgradeTime);

        vm.prank(upgrader);
        accessManager.execute(
            address(nvmConfig), abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(nvmConfigV2Impl), bytes('')))
        );

        NVMConfigV2 nvmConfigV2 = NVMConfigV2(address(nvmConfig));

        vm.prank(governor);
        nvmConfigV2.initializeV2(newVersion);

        assertEq(nvmConfigV2.getVersion(), newVersion);
    }

    function test_getNetworkFee() public view {
        uint256 networkFee = nvmConfig.getNetworkFee();
        assertEq(networkFee, 100);
    }

    function test_getFeeReceiver() public view {
        address feeReceiver = nvmConfig.getFeeReceiver();
        assertEq(feeReceiver, owner);
    }
}
