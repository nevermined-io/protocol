// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../Constants.sol";
import {DeployConfig} from "./DeployConfig.sol";
import {DeployNVMConfig} from "./DeployNVMConfig.sol";
import {DeployLibraries} from "./DeployLibraries.sol";
import {DeployCoreContracts} from "./DeployCoreContracts.sol";
import {DeployNFTContracts} from "./DeployNFTContracts.sol";
import {DeployConditions} from "./DeployConditions.sol";
import {DeployTemplates} from "./DeployTemplates.sol";
import {ManagePermissions} from "./ManagePermissions.sol";
import {NVMConfig} from "../../contracts/NVMConfig.sol";
import {TokenUtils} from "../../contracts/utils/TokenUtils.sol";
import {AssetsRegistry} from "../../contracts/AssetsRegistry.sol";
import {AgreementsStore} from "../../contracts/agreements/AgreementsStore.sol";
import {PaymentsVault} from "../../contracts/PaymentsVault.sol";
import {NFT1155Credits} from "../../contracts/token/NFT1155Credits.sol";
import {LockPaymentCondition} from "../../contracts/conditions/LockPaymentCondition.sol";
import {TransferCreditsCondition} from "../../contracts/conditions/TransferCreditsCondition.sol";
import {DistributePaymentsCondition} from "../../contracts/conditions/DistributePaymentsCondition.sol";
import {FixedPaymentTemplate} from "../../contracts/agreements/FixedPaymentTemplate.sol";

contract DeployAll is Script, DeployConfig {
    function run() public {
        // Load the deployment scripts
        DeployNVMConfig deployNVMConfig = new DeployNVMConfig();
        DeployLibraries deployLibraries = new DeployLibraries();
        DeployCoreContracts deployCoreContracts = new DeployCoreContracts();
        DeployNFTContracts deployNFTContracts = new DeployNFTContracts();
        DeployConditions deployConditions = new DeployConditions();
        DeployTemplates deployTemplates = new DeployTemplates();
        ManagePermissions managePermissions = new ManagePermissions();
        
        // Execute the deployments in order
        // 1. Deploy NVMConfig
        NVMConfig nvmConfig = deployNVMConfig.run();
        console.log("NVMConfig deployed at:", address(nvmConfig));
        
        // 2. Deploy Libraries
        TokenUtils tokenUtils = deployLibraries.run();
        console.log("TokenUtils deployed at:", address(tokenUtils));
        
        // 3. Deploy Core Contracts
        (
            AssetsRegistry assetsRegistry,
            AgreementsStore agreementsStore,
            PaymentsVault paymentsVault
        ) = deployCoreContracts.run(address(nvmConfig));
        console.log("AssetsRegistry deployed at:", address(assetsRegistry));
        console.log("AgreementsStore deployed at:", address(agreementsStore));
        console.log("PaymentsVault deployed at:", address(paymentsVault));
        
        // 4. Deploy NFT Contracts
        NFT1155Credits nftCredits = deployNFTContracts.run(address(nvmConfig));
        console.log("NFT1155Credits deployed at:", address(nftCredits));
        
        // 5. Deploy Conditions
        (
            LockPaymentCondition lockPaymentCondition,
            TransferCreditsCondition transferCreditsCondition,
            DistributePaymentsCondition distributePaymentsCondition
        ) = deployConditions.run(
            address(nvmConfig),
            address(assetsRegistry),
            address(agreementsStore),
            address(paymentsVault),
            address(tokenUtils)
        );
        console.log("LockPaymentCondition deployed at:", address(lockPaymentCondition));
        console.log("TransferCreditsCondition deployed at:", address(transferCreditsCondition));
        console.log("DistributePaymentsCondition deployed at:", address(distributePaymentsCondition));
        
        // 6. Deploy Templates
        FixedPaymentTemplate fixedPaymentTemplate = deployTemplates.run(
            address(nvmConfig),
            address(agreementsStore),
            address(lockPaymentCondition),
            address(transferCreditsCondition),
            address(distributePaymentsCondition)
        );
        console.log("FixedPaymentTemplate deployed at:", address(fixedPaymentTemplate));
        
        // 7. Manage Permissions
        managePermissions.run(
            address(nvmConfig),
            address(paymentsVault),
            address(nftCredits),
            address(lockPaymentCondition),
            address(distributePaymentsCondition),
            address(transferCreditsCondition)
        );
        console.log("Permissions granted successfully");
        
        // Write deployment addresses to a file for reference
        string memory deploymentInfo = string(abi.encodePacked(
            "NVMConfig: ", vm.toString(address(nvmConfig)), "\n",
            "TokenUtils: ", vm.toString(address(tokenUtils)), "\n",
            "AssetsRegistry: ", vm.toString(address(assetsRegistry)), "\n",
            "AgreementsStore: ", vm.toString(address(agreementsStore)), "\n",
            "PaymentsVault: ", vm.toString(address(paymentsVault)), "\n",
            "NFT1155Credits: ", vm.toString(address(nftCredits)), "\n",
            "LockPaymentCondition: ", vm.toString(address(lockPaymentCondition)), "\n",
            "TransferCreditsCondition: ", vm.toString(address(transferCreditsCondition)), "\n",
            "DistributePaymentsCondition: ", vm.toString(address(distributePaymentsCondition)), "\n",
            "FixedPaymentTemplate: ", vm.toString(address(fixedPaymentTemplate)), "\n"
        ));
        
        vm.writeFile("./deployments/latest.txt", deploymentInfo);
        console.log("Deployment addresses written to ./deployments/latest.txt");
    }
}
