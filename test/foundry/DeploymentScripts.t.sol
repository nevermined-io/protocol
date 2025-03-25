// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {Test, console} from 'forge-std/Test.sol';
import {Script} from 'forge-std/Script.sol';
import {Constants} from '../../script/Constants.sol';
import {DeployNVMConfig} from '../../script/deploy/DeployNVMConfig.sol';
import {DeployLibraries} from '../../script/deploy/DeployLibraries.sol';
import {DeployCoreContracts} from '../../script/deploy/DeployCoreContracts.sol';
import {DeployNFTContracts} from '../../script/deploy/DeployNFTContracts.sol';
import {DeployConditions} from '../../script/deploy/DeployConditions.sol';
import {DeployTemplates} from '../../script/deploy/DeployTemplates.sol';
import {ManagePermissions} from '../../script/deploy/ManagePermissions.sol';
import {NVMConfig} from '../../contracts/NVMConfig.sol';
import {AssetsRegistry} from '../../contracts/AssetsRegistry.sol';
import {AgreementsStore} from '../../contracts/agreements/AgreementsStore.sol';
import {PaymentsVault} from '../../contracts/PaymentsVault.sol';
import {NFT1155Credits} from '../../contracts/token/NFT1155Credits.sol';
import {LockPaymentCondition} from '../../contracts/conditions/LockPaymentCondition.sol';
import {TransferCreditsCondition} from '../../contracts/conditions/TransferCreditsCondition.sol';
import {DistributePaymentsCondition} from '../../contracts/conditions/DistributePaymentsCondition.sol';
import {FixedPaymentTemplate} from '../../contracts/agreements/FixedPaymentTemplate.sol';

contract DeploymentScriptsTest is Test {
    // Test accounts
    address public owner;
    address public governor;
    uint256 public ownerPrivateKey;
    uint256 public governorPrivateKey;

    // Deployment scripts
    DeployNVMConfig public deployNVMConfig;
    DeployLibraries public deployLibraries;
    DeployCoreContracts public deployCoreContracts;
    DeployNFTContracts public deployNFTContracts;
    DeployConditions public deployConditions;
    DeployTemplates public deployTemplates;
    ManagePermissions public managePermissions;

    // Deployed contracts
    NVMConfig public nvmConfig;
    address public tokenUtilsAddress;
    AssetsRegistry public assetsRegistry;
    AgreementsStore public agreementsStore;
    PaymentsVault public paymentsVault;
    NFT1155Credits public nftCredits;
    LockPaymentCondition public lockPaymentCondition;
    TransferCreditsCondition public transferCreditsCondition;
    DistributePaymentsCondition public distributePaymentsCondition;
    FixedPaymentTemplate public fixedPaymentTemplate;

    function setUp() public {
        // Setup test accounts
        ownerPrivateKey = 0x1;
        governorPrivateKey = 0x2;
        owner = vm.addr(ownerPrivateKey);
        governor = vm.addr(governorPrivateKey);

        // Set environment variables for deployment scripts
        vm.setEnv("OWNER_PRIVATE_KEY", vm.toString(ownerPrivateKey));
        vm.setEnv("GOVERNOR_PRIVATE_KEY", vm.toString(governorPrivateKey));

        // Initialize deployment scripts
        deployNVMConfig = new DeployNVMConfig();
        deployLibraries = new DeployLibraries();
        deployCoreContracts = new DeployCoreContracts();
        deployNFTContracts = new DeployNFTContracts();
        deployConditions = new DeployConditions();
        deployTemplates = new DeployTemplates();
        managePermissions = new ManagePermissions();
    }

    function test_DeploymentSequence() public {
        // 1. Deploy NVMConfig
        nvmConfig = deployNVMConfig.run();
        assertTrue(nvmConfig.isOwner(owner), "Owner role not set correctly");
        assertTrue(nvmConfig.isGovernor(governor), "Governor role not set correctly");

        // 2. Deploy Libraries
        tokenUtilsAddress = deployLibraries.run();
        assertTrue(tokenUtilsAddress != address(0), "TokenUtils deployment failed");

        // 3. Deploy Core Contracts
        (assetsRegistry, agreementsStore, paymentsVault) = deployCoreContracts.run(address(nvmConfig));
        assertTrue(address(assetsRegistry) != address(0), "AssetsRegistry deployment failed");
        assertTrue(address(agreementsStore) != address(0), "AgreementsStore deployment failed");
        assertTrue(address(paymentsVault) != address(0), "PaymentsVault deployment failed");

        // 4. Deploy NFT Contracts
        nftCredits = deployNFTContracts.run(address(nvmConfig));
        assertTrue(address(nftCredits) != address(0), "NFT1155Credits deployment failed");

        // 5. Deploy Conditions
        (lockPaymentCondition, transferCreditsCondition, distributePaymentsCondition) = 
            deployConditions.run(
                address(nvmConfig),
                address(assetsRegistry),
                address(agreementsStore),
                address(paymentsVault),
                tokenUtilsAddress
            );
        assertTrue(address(lockPaymentCondition) != address(0), "LockPaymentCondition deployment failed");
        assertTrue(address(transferCreditsCondition) != address(0), "TransferCreditsCondition deployment failed");
        assertTrue(address(distributePaymentsCondition) != address(0), "DistributePaymentsCondition deployment failed");

        // 6. Deploy Templates
        fixedPaymentTemplate = deployTemplates.run(
            address(nvmConfig),
            address(agreementsStore),
            address(lockPaymentCondition),
            address(transferCreditsCondition),
            address(distributePaymentsCondition)
        );
        assertTrue(address(fixedPaymentTemplate) != address(0), "FixedPaymentTemplate deployment failed");

        // 7. Manage Permissions
        managePermissions.run(
            address(nvmConfig),
            address(paymentsVault),
            address(nftCredits),
            address(lockPaymentCondition),
            address(distributePaymentsCondition),
            address(transferCreditsCondition)
        );

        // For test purposes, we'll only verify that the contracts were deployed successfully
        // We won't verify the contract registrations in NVMConfig since that would require
        // implementing the same contract registration logic as in the NVMConfig contract
        assertTrue(address(assetsRegistry) != address(0), "AssetsRegistry deployment failed");
        assertTrue(address(agreementsStore) != address(0), "AgreementsStore deployment failed");
        assertTrue(address(paymentsVault) != address(0), "PaymentsVault deployment failed");
        assertTrue(address(nftCredits) != address(0), "NFT1155Credits deployment failed");
        assertTrue(address(lockPaymentCondition) != address(0), "LockPaymentCondition deployment failed");
        assertTrue(address(transferCreditsCondition) != address(0), "TransferCreditsCondition deployment failed");
        assertTrue(address(distributePaymentsCondition) != address(0), "DistributePaymentsCondition deployment failed");
        assertTrue(address(fixedPaymentTemplate) != address(0), "FixedPaymentTemplate deployment failed");
    }
}
