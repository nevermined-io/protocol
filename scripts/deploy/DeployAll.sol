// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Constants} from "../Constants.sol";
import {DeployConfig} from "./DeployConfig.sol";
import {DeployNVMConfig} from "./DeployNVMConfig.sol";
import {DeployLibraries} from "./DeployLibraries.sol";
import {DeployCoreContracts} from "./DeployCoreContracts.sol";
import {DeployNFTContracts} from "./DeployNFTContracts.sol";
import {DeployConditions} from "./DeployConditions.sol";
import {DeployTemplates} from "./DeployTemplates.sol";
// import {ManagePermissions} from "./ManagePermissions.sol";
import {NVMConfig} from "../../contracts/NVMConfig.sol";
import {TokenUtils} from "../../contracts/utils/TokenUtils.sol";
import {AssetsRegistry} from "../../contracts/AssetsRegistry.sol";
import {AgreementsStore} from "../../contracts/agreements/AgreementsStore.sol";
import {PaymentsVault} from "../../contracts/PaymentsVault.sol";
import {NFT1155Credits} from "../../contracts/token/NFT1155Credits.sol";
import {NFT1155ExpirableCredits} from "../../contracts/token/NFT1155ExpirableCredits.sol";
import {LockPaymentCondition} from "../../contracts/conditions/LockPaymentCondition.sol";
import {TransferCreditsCondition} from "../../contracts/conditions/TransferCreditsCondition.sol";
import {DistributePaymentsCondition} from "../../contracts/conditions/DistributePaymentsCondition.sol";
import {FixedPaymentTemplate} from "../../contracts/agreements/FixedPaymentTemplate.sol";
import {OwnerGrantRoles} from "./OwnerGrantRoles.sol";

contract DeployAll is Script, DeployConfig {
    function run() public {
        
        address ownerAddress = msg.sender;
        address governorAddress = vm.envOr('GOVERNOR_ADDRESS', msg.sender);        

        string memory packageJson = vm.envOr('PACKAGE_JSON', string('./package.json'));
        string memory version = vm.parseJsonString(vm.readFile(packageJson), '$.version');

        string memory outputJson = vm.envOr('DEPLOYMENT_ADDRESSES_JSON', string(
            abi.encodePacked(
            './deployments/deployment-v', version ,'-', vm.toString(block.chainid) ,'.json')));

        console.log("Deploying all contracts with addresses:");
        console.log("\tOwner:", ownerAddress);
        console.log("\tGovernor:", governorAddress);

        console.log("Version: ", version);

        // Load the deployment scripts
        DeployNVMConfig deployNVMConfig = new DeployNVMConfig();
        DeployLibraries deployLibraries = new DeployLibraries();
        DeployCoreContracts deployCoreContracts = new DeployCoreContracts();
        DeployNFTContracts deployNFTContracts = new DeployNFTContracts();
        DeployConditions deployConditions = new DeployConditions();
        DeployTemplates deployTemplates = new DeployTemplates();
        OwnerGrantRoles ownerGrantRoles = new OwnerGrantRoles();
        // ManagePermissions managePermissions = new ManagePermissions();
        
        // Execute the deployments in order
        // 1. Deploy NVMConfig
        NVMConfig nvmConfig = deployNVMConfig.run(ownerAddress, governorAddress);
        console.log("NVMConfig deployed at:", address(nvmConfig));
        
        // 2. Deploy Libraries
        address tokenUtilsAddress = deployLibraries.run(ownerAddress);
        console.log("TokenUtils deployed at:", tokenUtilsAddress);
        
        // 3. Deploy Core Contracts
        (
            AssetsRegistry assetsRegistry,
            AgreementsStore agreementsStore,
            PaymentsVault paymentsVault
        ) = deployCoreContracts.run(address(nvmConfig), ownerAddress);
        console.log("AssetsRegistry deployed at:", address(assetsRegistry));
        console.log("AgreementsStore deployed at:", address(agreementsStore));
        console.log("PaymentsVault deployed at:", address(paymentsVault));
        
        // 4. Deploy NFT Contracts
        ( 
            NFT1155Credits nftCredits,
            NFT1155ExpirableCredits nftExpirableCredits
        ) = deployNFTContracts.run(address(nvmConfig), address(assetsRegistry), ownerAddress);

        console.log("NFT1155Credits deployed at:", address(nftCredits));
        console.log("NFT1155ExpirableCredits deployed at:", address(nftExpirableCredits));
        
        // 5. Deploy Conditions
        (
            LockPaymentCondition lockPaymentCondition,
            TransferCreditsCondition transferCreditsCondition,
            DistributePaymentsCondition distributePaymentsCondition
        ) = deployConditions.run(
            ownerAddress,
            address(nvmConfig),
            address(assetsRegistry),
            address(agreementsStore),
            address(paymentsVault),
            tokenUtilsAddress
        );
        console.log("LockPaymentCondition deployed at:", address(lockPaymentCondition));
        console.log("TransferCreditsCondition deployed at:", address(transferCreditsCondition));
        console.log("DistributePaymentsCondition deployed at:", address(distributePaymentsCondition));
        
    
        // 6. Deploy Templates
        FixedPaymentTemplate fixedPaymentTemplate = deployTemplates.run(
            ownerAddress,
            address(nvmConfig),
            address(agreementsStore),
            address(lockPaymentCondition),
            address(transferCreditsCondition),
            address(distributePaymentsCondition)
        );
        console.log("FixedPaymentTemplate deployed at:", address(fixedPaymentTemplate));
        
        ownerGrantRoles.run(
            address(nvmConfig),
            ownerAddress,
            address(paymentsVault),
            address(nftCredits),
            address(lockPaymentCondition),
            address(transferCreditsCondition),
            address(distributePaymentsCondition)
        );
        console.log("Roles granted successfully by Owner");
        
        string memory deploymentJson = string(abi.encodePacked(
            '{\n',
            '  "version": "', version, '",\n',
            '  "owner": "', vm.toString(ownerAddress), '",\n',
            '  "governor": "', vm.toString(governorAddress), '",\n',
            '  "chainId": "', vm.toString(block.chainid) ,'",\n',
            '  "deployedAt": "', vm.toString(block.timestamp) ,'",\n',
            '  "contracts": {\n',
            '    "NVMConfig": "', vm.toString(address(nvmConfig)), '",\n',
            '    "TokenUtils": "', vm.toString(tokenUtilsAddress), '",\n',
            '    "AssetsRegistry": "', vm.toString(address(assetsRegistry)), '",\n',
            '    "AgreementsStore": "', vm.toString(address(agreementsStore)), '",\n',
            '    "PaymentsVault": "', vm.toString(address(paymentsVault)), '",\n',
            '    "NFT1155Credits": "', vm.toString(address(nftCredits)), '",\n',
            '    "NFT1155ExpirableCredits": "', vm.toString(address(nftExpirableCredits)), '",\n',
            '    "LockPaymentCondition": "', vm.toString(address(lockPaymentCondition)), '",\n',
            '    "TransferCreditsCondition": "', vm.toString(address(transferCreditsCondition)), '",\n',
            '    "DistributePaymentsCondition": "', vm.toString(address(distributePaymentsCondition)), '",\n',
            '    "FixedPaymentTemplate": "', vm.toString(address(fixedPaymentTemplate)), '"\n',
            '  }\n',
            '}\n'
        ));
        
        vm.writeJson(deploymentJson, outputJson);
        console.log('Deployment addresses written to %s', outputJson);
        
        
    }
}
