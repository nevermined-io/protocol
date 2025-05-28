// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.30;

import {INVMConfig} from '../../contracts/interfaces/INVMConfig.sol';
import {Constants} from '../../scripts/Constants.sol';
import {Script} from 'forge-std/Script.sol';
import {Test, console} from 'forge-std/Test.sol';

// Import MockNVMConfig from DeploymentScripts.t.sol
import {MockNVMConfig} from './DeploymentScripts.t.sol';

// Mock upgrade contract for testing
contract MockUpgradeContract is Test {
    function run(address nvmConfigAddress, bytes32 contractName, address newImplementation) public returns (bool) {
        MockNVMConfig nvmConfig = MockNVMConfig(nvmConfigAddress);

        // Get current version
        uint256 currentVersion = nvmConfig.getContractVersion(contractName);

        // Register new implementation with incremented version
        return nvmConfig.registerContract(contractName, newImplementation, currentVersion + 1);
    }
}

contract UpgradeScriptsTest is Test {
    // Test accounts
    address public owner;
    address public governor;
    uint256 public ownerPrivateKey;
    uint256 public governorPrivateKey;

    // Mock NVMConfig
    MockNVMConfig public mockNvmConfig;

    // Mock upgrade contract
    MockUpgradeContract public mockUpgradeContract;

    function setUp() public {
        // Setup test accounts
        ownerPrivateKey = 0x1;
        governorPrivateKey = 0x2;
        owner = vm.addr(ownerPrivateKey);
        governor = vm.addr(governorPrivateKey);

        // Set environment variables for deployment scripts using mnemonic approach
        string memory testMnemonic = 'test test test test test test test test test test test junk';
        vm.setEnv('MNEMONIC', testMnemonic);
        vm.setEnv('OWNER_INDEX', '0');
        vm.setEnv('GOVERNOR_INDEX', '1');

        // Deploy mock NVMConfig
        mockNvmConfig = new MockNVMConfig(owner, governor);

        // Initialize mock upgrade contract
        mockUpgradeContract = new MockUpgradeContract();
    }

    function test_MockUpgradeContract() public {
        // Register initial contract version
        bytes32 testContractName = keccak256('TestContract');
        address initialImplementation = address(0x123);
        uint256 initialVersion = 1;

        vm.prank(governor);
        bool success = mockNvmConfig.registerContract(testContractName, initialImplementation, initialVersion);
        assertTrue(success, 'Initial contract registration failed');

        // Verify initial registration
        assertEq(
            mockNvmConfig.getContractVersion(testContractName), initialVersion, 'Initial version not set correctly'
        );

        // Deploy new implementation
        address newImplementation = address(0x456);

        // Upgrade contract
        vm.prank(governor);
        success = mockUpgradeContract.run(address(mockNvmConfig), testContractName, newImplementation);
        assertTrue(success, 'Contract upgrade failed');

        // Verify upgrade
        assertEq(mockNvmConfig.getContractVersion(testContractName), initialVersion + 1, 'Version not incremented');
        assertEq(
            mockNvmConfig.getContractAddress(testContractName), newImplementation, 'New implementation not registered'
        );
    }

    function test_MockUpgradeMultipleContracts() public {
        // Register initial contracts
        bytes32 testContract1Name = keccak256('TestContract1');
        bytes32 testContract2Name = keccak256('TestContract2');
        address initialImplementation1 = address(0x123);
        address initialImplementation2 = address(0x789);
        uint256 initialVersion = 1;

        vm.startPrank(governor);
        bool success1 = mockNvmConfig.registerContract(testContract1Name, initialImplementation1, initialVersion);
        bool success2 = mockNvmConfig.registerContract(testContract2Name, initialImplementation2, initialVersion);
        vm.stopPrank();

        assertTrue(success1 && success2, 'Initial contract registrations failed');

        // Deploy new implementations
        address newImplementation1 = address(0x456);
        address newImplementation2 = address(0xabc);

        // Upgrade contracts
        vm.startPrank(governor);
        bool upgradeSuccess1 = mockUpgradeContract.run(address(mockNvmConfig), testContract1Name, newImplementation1);

        bool upgradeSuccess2 = mockUpgradeContract.run(address(mockNvmConfig), testContract2Name, newImplementation2);
        vm.stopPrank();

        assertTrue(upgradeSuccess1 && upgradeSuccess2, 'Contract upgrades failed');

        // Verify upgrades
        assertEq(mockNvmConfig.getContractVersion(testContract1Name), initialVersion + 1, 'Version 1 not incremented');
        assertEq(mockNvmConfig.getContractVersion(testContract2Name), initialVersion + 1, 'Version 2 not incremented');
        assertEq(
            mockNvmConfig.getContractAddress(testContract1Name),
            newImplementation1,
            'New implementation 1 not registered'
        );
        assertEq(
            mockNvmConfig.getContractAddress(testContract2Name),
            newImplementation2,
            'New implementation 2 not registered'
        );
    }
}
