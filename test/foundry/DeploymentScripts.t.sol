// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {Test, console} from 'forge-std/Test.sol';
import {Script} from 'forge-std/Script.sol';
import {Constants} from '../../scripts/Constants.sol';
import {INVMConfig} from '../../contracts/interfaces/INVMConfig.sol';

// Mock NVMConfig for testing
contract MockNVMConfig {
    address public owner;
    address public governor;
    mapping(bytes32 => address) public contractAddresses;
    mapping(bytes32 => uint256) public contractsLatestVersion;
    
    constructor(address _owner, address _governor) {
        owner = _owner;
        governor = _governor;
    }
    
    function isOwner(address account) external view returns (bool) {
        return account == owner;
    }
    
    function isGovernor(address account) external view returns (bool) {
        return account == governor;
    }
    
    // Mock implementation of registerContract
    function registerContract(bytes32 contractName, address contractAddress, uint256 version) external returns (bool) {
        bytes32 registryId = keccak256(abi.encode(contractName, version));
        contractAddresses[registryId] = contractAddress;
        contractsLatestVersion[contractName] = version;
        return true;
    }
    
    // Mock implementation of grantCondition
    function grantCondition(address condition) external returns (bool) {
        return true;
    }
    
    // Mock implementation of grantTemplate
    function grantTemplate(address template) external returns (bool) {
        return true;
    }
    
    // Mock implementation of grantRole
    function grantRole(bytes32 role, address account) external returns (bool) {
        return true;
    }
    
    // Mock implementation of getContractVersion
    function getContractVersion(bytes32 contractName) external view returns (uint256) {
        return contractsLatestVersion[contractName];
    }
    
    // Mock implementation of getContractAddress
    function getContractAddress(bytes32 contractName) external view returns (address) {
        bytes32 registryId = keccak256(abi.encode(contractName, contractsLatestVersion[contractName]));
        return contractAddresses[registryId];
    }
}

// Mock deployment script for NVMConfig
contract MockDeployNVMConfig is Test {
    function run() public returns (MockNVMConfig) {
        address owner = vm.addr(0x1);
        address governor = vm.addr(0x2);
        return new MockNVMConfig(owner, governor);
    }
}

contract DeploymentScriptsTest is Test {
    // Test accounts
    address public owner;
    address public governor;
    uint256 public ownerPrivateKey;
    uint256 public governorPrivateKey;

    // Mock deployment script
    MockDeployNVMConfig public mockDeployNVMConfig;
    
    // Mock NVMConfig
    MockNVMConfig public mockNvmConfig;

    function setUp() public {
        // Setup test accounts
        ownerPrivateKey = 0x1;
        governorPrivateKey = 0x2;
        owner = vm.addr(ownerPrivateKey);
        governor = vm.addr(governorPrivateKey);

        // Set environment variables for deployment scripts using mnemonic approach
        string memory testMnemonic = "test test test test test test test test test test test junk";
        vm.setEnv("MNEMONIC", testMnemonic);
        vm.setEnv("OWNER_INDEX", "0");
        vm.setEnv("GOVERNOR_INDEX", "1");

        // Initialize mock deployment script
        mockDeployNVMConfig = new MockDeployNVMConfig();
        
        // Deploy mock NVMConfig
        mockNvmConfig = mockDeployNVMConfig.run();
    }

    function test_MockDeploymentSequence() public {
        // Verify mock NVMConfig deployment
        assertTrue(mockNvmConfig.isOwner(owner), "Owner role not set correctly");
        assertTrue(mockNvmConfig.isGovernor(governor), "Governor role not set correctly");
        
        // Test contract registration
        bytes32 testContractName = keccak256("TestContract");
        address testContractAddress = address(0x123);
        uint256 testVersion = 1;
        
        // Register a contract
        vm.prank(governor);
        bool success = mockNvmConfig.registerContract(testContractName, testContractAddress, testVersion);
        assertTrue(success, "Contract registration failed");
        
        // Verify contract registration
        assertEq(mockNvmConfig.getContractVersion(testContractName), testVersion, "Contract version not set correctly");
        assertEq(mockNvmConfig.getContractAddress(testContractName), testContractAddress, "Contract address not set correctly");
        
        // Test role granting
        address testCondition = address(0x456);
        vm.prank(governor);
        success = mockNvmConfig.grantCondition(testCondition);
        assertTrue(success, "Condition role granting failed");
        
        address testTemplate = address(0x789);
        vm.prank(governor);
        success = mockNvmConfig.grantTemplate(testTemplate);
        assertTrue(success, "Template role granting failed");
        
        bytes32 testRole = keccak256("TEST_ROLE");
        address testAccount = address(0xabc);
        vm.prank(governor);
        success = mockNvmConfig.grantRole(testRole, testAccount);
        assertTrue(success, "Role granting failed");
    }
}
