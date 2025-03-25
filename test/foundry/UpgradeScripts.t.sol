// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {Test, console} from 'forge-std/Test.sol';
import {Script} from 'forge-std/Script.sol';
import {Constants} from '../../script/Constants.sol';
import {DeployNVMConfig} from '../../script/deploy/DeployNVMConfig.sol';
import {DeployCoreContracts} from '../../script/deploy/DeployCoreContracts.sol';
import {UpgradeContract} from '../../script/upgrade/UpgradeContract.sol';
import {NVMConfig} from '../../contracts/NVMConfig.sol';
import {AssetsRegistry} from '../../contracts/AssetsRegistry.sol';
import {AgreementsStore} from '../../contracts/agreements/AgreementsStore.sol';

contract UpgradeScriptsTest is Test {
    // Test accounts
    address public owner;
    address public governor;
    uint256 public ownerPrivateKey;
    uint256 public governorPrivateKey;

    // Deployment and upgrade scripts
    DeployNVMConfig public deployNVMConfig;
    DeployCoreContracts public deployCoreContracts;
    UpgradeContract public upgradeContract;

    // Deployed contracts
    NVMConfig public nvmConfig;
    AssetsRegistry public assetsRegistry;
    AgreementsStore public agreementsStore;

    function setUp() public {
        // Setup test accounts
        ownerPrivateKey = 0x1;
        governorPrivateKey = 0x2;
        owner = vm.addr(ownerPrivateKey);
        governor = vm.addr(governorPrivateKey);

        // Set environment variables for deployment scripts
        vm.setEnv("OWNER_PRIVATE_KEY", vm.toString(ownerPrivateKey));
        vm.setEnv("GOVERNOR_PRIVATE_KEY", vm.toString(governorPrivateKey));

        // Initialize deployment and upgrade scripts
        deployNVMConfig = new DeployNVMConfig();
        deployCoreContracts = new DeployCoreContracts();
        upgradeContract = new UpgradeContract();

        // Start prank as owner for initial setup
        vm.startPrank(owner);

        // Deploy NVMConfig
        nvmConfig = deployNVMConfig.run();
        
        // Deploy core contracts
        (assetsRegistry, agreementsStore,) = deployCoreContracts.run(address(nvmConfig));
    }

    function test_UpgradeContract() public {
        // Deploy a new version of AssetsRegistry
        AssetsRegistry newAssetsRegistry = new AssetsRegistry();
        
        // Get current version of AssetsRegistry
        (bool success1, bytes memory data1) = address(nvmConfig).call(
            abi.encodeWithSignature("getContractVersion(bytes32)", Constants.HASH_ASSETS_REGISTRY)
        );
        require(success1, "Failed to get AssetsRegistry version");
        uint256 currentVersion = abi.decode(data1, (uint256));
        
        // Upgrade AssetsRegistry
        upgradeContract.run(
            address(nvmConfig),
            Constants.HASH_ASSETS_REGISTRY,
            address(newAssetsRegistry)
        );
        
        // Verify the upgrade
        (bool success2, bytes memory data2) = address(nvmConfig).call(
            abi.encodeWithSignature("getContractVersion(bytes32)", Constants.HASH_ASSETS_REGISTRY)
        );
        require(success2, "Failed to get updated AssetsRegistry version");
        uint256 newVersion = abi.decode(data2, (uint256));
        
        // Check version was incremented
        assertEq(newVersion, currentVersion + 1, "Contract version not incremented");
        
        // Check address was updated
        (bool success3, bytes memory data3) = address(nvmConfig).call(
            abi.encodeWithSignature("getContractAddress(bytes32)", Constants.HASH_ASSETS_REGISTRY)
        );
        require(success3, "Failed to get updated AssetsRegistry address");
        address updatedAddress = abi.decode(data3, (address));
        
        assertEq(updatedAddress, address(newAssetsRegistry), "Contract address not updated");
    }
    
    function test_UpgradeMultipleContracts() public {
        // Deploy new versions of contracts
        AssetsRegistry newAssetsRegistry = new AssetsRegistry();
        AgreementsStore newAgreementsStore = new AgreementsStore();
        
        // Upgrade AssetsRegistry
        upgradeContract.run(
            address(nvmConfig),
            Constants.HASH_ASSETS_REGISTRY,
            address(newAssetsRegistry)
        );
        
        // Upgrade AgreementsStore
        upgradeContract.run(
            address(nvmConfig),
            Constants.HASH_AGREEMENTS_STORE,
            address(newAgreementsStore)
        );
        
        // Verify both upgrades
        (bool success1, bytes memory data1) = address(nvmConfig).call(
            abi.encodeWithSignature("getContractAddress(bytes32)", Constants.HASH_ASSETS_REGISTRY)
        );
        require(success1, "Failed to get updated AssetsRegistry address");
        address updatedAssetsRegistryAddress = abi.decode(data1, (address));
        
        (bool success2, bytes memory data2) = address(nvmConfig).call(
            abi.encodeWithSignature("getContractAddress(bytes32)", Constants.HASH_AGREEMENTS_STORE)
        );
        require(success2, "Failed to get updated AgreementsStore address");
        address updatedAgreementsStoreAddress = abi.decode(data2, (address));
        
        assertEq(updatedAssetsRegistryAddress, address(newAssetsRegistry), "AssetsRegistry address not updated");
        assertEq(updatedAgreementsStoreAddress, address(newAgreementsStore), "AgreementsStore address not updated");
    }
}
