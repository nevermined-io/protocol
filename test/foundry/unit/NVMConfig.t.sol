// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {NVMConfig} from '../../../contracts/NVMConfig.sol';
import {INVMConfig} from '../../../contracts/interfaces/INVMConfig.sol';

import {NVMConfigV2} from '../../../contracts/mock/NVMConfigV2.sol';
import {BaseTest} from '../common/BaseTest.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

import {GOVERNOR_ROLE} from '../../../contracts/common/Roles.sol';
import {IAccessManaged} from '@openzeppelin/contracts/access/manager/IAccessManaged.sol';

contract NVMConfigTest is BaseTest {
    address public newGovernor;

    function setUp() public override {
        super.setUp();

        vm.prank(governor);
        nvmConfig.setNetworkFees(100, owner);

        newGovernor = makeAddr('newGovernor');
    }

    function test_setNetworkFees() public {
        vm.prank(governor);

        // The setNetworkFees function emits two events, one for networkFee and one for feeReceiver
        vm.expectEmit(true, true, true, true);
        emit INVMConfig.NeverminedConfigChange(governor, keccak256('networkFee'), abi.encodePacked(uint256(200)));

        vm.expectEmit(true, true, true, true);
        emit INVMConfig.NeverminedConfigChange(governor, keccak256('feeReceiver'), abi.encodePacked(governor));

        nvmConfig.setNetworkFees(200, governor);

        assertEq(nvmConfig.getNetworkFee(), 200);
        assertEq(nvmConfig.getFeeReceiver(), governor);
    }

    function test_setNetworkFees_onlyGovernor() public {
        address nonGovernor = makeAddr('nonGovernor');

        vm.prank(nonGovernor);
        vm.expectPartialRevert(IAccessManaged.AccessManagedUnauthorized.selector);
        nvmConfig.setNetworkFees(200, governor);
    }

    function test_setNetworkFees_invalidFee() public {
        vm.prank(governor);
        vm.expectPartialRevert(INVMConfig.InvalidNetworkFee.selector);
        nvmConfig.setNetworkFees(9900000, governor);
    }

    function test_setNetworkFees_invalidReceiver() public {
        vm.prank(governor);
        vm.expectPartialRevert(INVMConfig.InvalidFeeReceiver.selector);
        nvmConfig.setNetworkFees(200, address(0));
    }

    function test_setParameter() public {
        bytes32 paramName = keccak256('myparam');
        bytes memory paramValue = abi.encodePacked('myvalue');

        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit INVMConfig.NeverminedConfigChange(governor, paramName, paramValue);
        nvmConfig.setParameter(paramName, paramValue);

        (bytes memory value, bool exists,) = nvmConfig.getParameter(paramName);
        assertTrue(exists);
        assertEq(keccak256(value), keccak256(paramValue));
    }

    function test_setParameter_onlyGovernor() public {
        bytes32 paramName = keccak256('myparam');
        bytes memory paramValue = abi.encodePacked('myvalue');

        address nonGovernor = makeAddr('nonGovernor');

        vm.prank(nonGovernor);
        vm.expectPartialRevert(IAccessManaged.AccessManagedUnauthorized.selector);
        nvmConfig.setParameter(paramName, paramValue);
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

    function test_getFeeDenominator() public view {
        uint256 denominator = nvmConfig.getFeeDenominator();
        assertEq(denominator, 1000000);
    }

    function test_parameterExists() public {
        bytes32 paramName = keccak256('testParam');

        // Initially parameter should not exist
        assertFalse(nvmConfig.parameterExists(paramName));

        // Set parameter
        vm.prank(governor);
        nvmConfig.setParameter(paramName, abi.encodePacked('testValue'));

        // Now parameter should exist
        assertTrue(nvmConfig.parameterExists(paramName));

        // Disable parameter
        vm.prank(governor);
        nvmConfig.disableParameter(paramName);

        // Parameter should no longer exist
        assertFalse(nvmConfig.parameterExists(paramName));
    }

    function test_disableParameter() public {
        bytes32 paramName = keccak256('testParam');
        bytes memory paramValue = abi.encodePacked('testValue');

        // Set parameter first
        vm.prank(governor);
        nvmConfig.setParameter(paramName, paramValue);

        // Disable parameter
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit INVMConfig.NeverminedConfigChange(governor, paramName, paramValue);
        nvmConfig.disableParameter(paramName);

        // Verify parameter is disabled
        (bytes memory value, bool isActive,) = nvmConfig.getParameter(paramName);
        assertFalse(isActive);
        assertEq(keccak256(value), keccak256(paramValue));
    }

    function test_disableParameter_onlyGovernor() public {
        bytes32 paramName = keccak256('testParam');
        bytes memory paramValue = abi.encodePacked('testValue');

        // Set parameter first
        vm.prank(governor);
        nvmConfig.setParameter(paramName, paramValue);

        // Try to disable parameter as non-governor
        address nonGovernor = makeAddr('nonGovernor');
        vm.prank(nonGovernor);
        vm.expectPartialRevert(IAccessManaged.AccessManagedUnauthorized.selector);
        nvmConfig.disableParameter(paramName);
    }

    function test_disableParameter_nonexistent() public {
        bytes32 paramName = keccak256('nonexistentParam');

        // Try to disable non-existent parameter
        vm.prank(governor);
        nvmConfig.disableParameter(paramName);

        // Verify parameter still doesn't exist
        assertFalse(nvmConfig.parameterExists(paramName));
    }

    function test_getNetworkFee_accessControl() public {
        // View function, no access control needed
        address nonGovernor = makeAddr('nonGovernor');
        vm.prank(nonGovernor);
        uint256 fee = nvmConfig.getNetworkFee();
        assertEq(fee, 100);
    }

    function test_getFeeReceiver_accessControl() public {
        // View function, no access control needed
        address nonGovernor = makeAddr('nonGovernor');
        vm.prank(nonGovernor);
        address receiver = nvmConfig.getFeeReceiver();
        assertEq(receiver, owner);
    }

    function test_getFeeDenominator_accessControl() public {
        // Pure function, no access control needed
        address nonGovernor = makeAddr('nonGovernor');
        vm.prank(nonGovernor);
        uint256 denominator = nvmConfig.getFeeDenominator();
        assertEq(denominator, 1000000);
    }

    function test_getParameter_accessControl() public {
        // View function, no access control needed
        bytes32 paramName = keccak256('testParam');
        bytes memory paramValue = abi.encodePacked('testValue');

        // Set parameter first
        vm.prank(governor);
        nvmConfig.setParameter(paramName, paramValue);

        // Read parameter as non-governor
        address nonGovernor = makeAddr('nonGovernor');
        vm.prank(nonGovernor);
        (bytes memory value, bool isActive,) = nvmConfig.getParameter(paramName);
        assertTrue(isActive);
        assertEq(keccak256(value), keccak256(paramValue));
    }

    function test_parameterExists_accessControl() public {
        // View function, no access control needed
        bytes32 paramName = keccak256('testParam');
        bytes memory paramValue = abi.encodePacked('testValue');

        // Set parameter first
        vm.prank(governor);
        nvmConfig.setParameter(paramName, paramValue);

        // Check parameter existence as non-governor
        address nonGovernor = makeAddr('nonGovernor');
        vm.prank(nonGovernor);
        assertTrue(nvmConfig.parameterExists(paramName));
    }
}
