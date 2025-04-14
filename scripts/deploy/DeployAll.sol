// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {AssetsRegistry} from '../../contracts/AssetsRegistry.sol';
import {NVMConfig} from '../../contracts/NVMConfig.sol';

import {PaymentsVault} from '../../contracts/PaymentsVault.sol';
import {AgreementsStore} from '../../contracts/agreements/AgreementsStore.sol';

import {FiatPaymentTemplate} from '../../contracts/agreements/FiatPaymentTemplate.sol';
import {FixedPaymentTemplate} from '../../contracts/agreements/FixedPaymentTemplate.sol';
import {DistributePaymentsCondition} from '../../contracts/conditions/DistributePaymentsCondition.sol';
import {FiatSettlementCondition} from '../../contracts/conditions/FiatSettlementCondition.sol';
import {LockPaymentCondition} from '../../contracts/conditions/LockPaymentCondition.sol';
import {TransferCreditsCondition} from '../../contracts/conditions/TransferCreditsCondition.sol';
import {NFT1155Credits} from '../../contracts/token/NFT1155Credits.sol';
import {NFT1155ExpirableCredits} from '../../contracts/token/NFT1155ExpirableCredits.sol';
import {TokenUtils} from '../../contracts/utils/TokenUtils.sol';
import {Constants} from '../Constants.sol';
import {DeployAccessManager} from './DeployAccessManager.sol';
import {DeployConditions} from './DeployConditions.sol';
import {DeployConfig} from './DeployConfig.sol';
import {DeployCoreContracts} from './DeployCoreContracts.sol';
import {DeployLibraries} from './DeployLibraries.sol';
import {DeployNFTContracts} from './DeployNFTContracts.sol';
import {DeployNVMConfig} from './DeployNVMConfig.sol';

import {DeployTemplates} from './DeployTemplates.sol';

import {OwnerGrantRoles} from './OwnerGrantRoles.sol';

import {UpgradeableContractDeploySalt} from './common/Types.sol';
import {AccessManager} from '@openzeppelin/contracts/access/manager/AccessManager.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract DeployAll is Script, DeployConfig {
    mapping(string contractName => UpgradeableContractDeploySalt implementationSalt) public deploymentSalt;

    constructor() {
        //// Set the deployment salts ////

        // AccessManager
        deploymentSalt[type(AccessManager).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('ACCESS_MANAGER_IMPL_1')),
            proxySalt: keccak256(abi.encodePacked('ACCESS_MANAGER_PROXY_1'))
        });

        // NVMConfig
        deploymentSalt[type(NVMConfig).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('NVM_CONFIG_IMPL_1')),
            proxySalt: keccak256(abi.encodePacked('NVM_CONFIG_PROXY_1'))
        });

        // TokenUtils
        deploymentSalt[type(TokenUtils).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('TOKEN_UTILS_IMPL_1')),
            proxySalt: keccak256(abi.encodePacked('TOKEN_UTILS_PROXY_1'))
        });

        // Core Contracts
        deploymentSalt[type(AssetsRegistry).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('ASSETS_REGISTRY_IMPL_1')),
            proxySalt: keccak256(abi.encodePacked('ASSETS_REGISTRY_PROXY_1'))
        });

        deploymentSalt[type(AgreementsStore).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('AGREEMENTS_STORE_IMPL_1')),
            proxySalt: keccak256(abi.encodePacked('AGREEMENTS_STORE_PROXY_1'))
        });

        deploymentSalt[type(PaymentsVault).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('PAYMENTS_VAULT_IMPL_1')),
            proxySalt: keccak256(abi.encodePacked('PAYMENTS_VAULT_PROXY_1'))
        });

        // NFT Contracts
        deploymentSalt[type(NFT1155Credits).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('NFT1155_CREDITS_IMPL_1')),
            proxySalt: keccak256(abi.encodePacked('NFT1155_CREDITS_PROXY_1'))
        });

        deploymentSalt[type(NFT1155ExpirableCredits).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('NFT1155_EXPIRABLE_CREDITS_IMPL_1')),
            proxySalt: keccak256(abi.encodePacked('NFT1155_EXPIRABLE_CREDITS_PROXY_1'))
        });

        // Conditions
        deploymentSalt[type(LockPaymentCondition).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('LOCK_PAYMENT_CONDITION_IMPL_1')),
            proxySalt: keccak256(abi.encodePacked('LOCK_PAYMENT_CONDITION_PROXY_1'))
        });

        deploymentSalt[type(TransferCreditsCondition).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('TRANSFER_CREDITS_CONDITION_IMPL_1')),
            proxySalt: keccak256(abi.encodePacked('TRANSFER_CREDITS_CONDITION_PROXY_1'))
        });

        deploymentSalt[type(DistributePaymentsCondition).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('DISTRIBUTE_PAYMENTS_CONDITION_IMPL_1')),
            proxySalt: keccak256(abi.encodePacked('DISTRIBUTE_PAYMENTS_CONDITION_PROXY_1'))
        });

        deploymentSalt[type(FiatSettlementCondition).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('FIAT_SETTLEMENT_CONDITION_IMPL_1')),
            proxySalt: keccak256(abi.encodePacked('FIAT_SETTLEMENT_CONDITION_PROXY_1'))
        });

        // Templates
        deploymentSalt[type(FixedPaymentTemplate).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('FIXED_PAYMENT_TEMPLATE_IMPL_1')),
            proxySalt: keccak256(abi.encodePacked('FIXED_PAYMENT_TEMPLATE_PROXY_1'))
        });

        deploymentSalt[type(FiatPaymentTemplate).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('FIAT_PAYMENT_TEMPLATE_IMPL_1')),
            proxySalt: keccak256(abi.encodePacked('FIAT_PAYMENT_TEMPLATE_PROXY_1'))
        });
    }

    function run() public {
        address ownerAddress = msg.sender;
        address governorAddress = vm.envOr('GOVERNOR_ADDRESS', msg.sender);

        string memory packageJson = vm.envOr('PACKAGE_JSON', string('./package.json'));
        string memory version = vm.parseJsonString(vm.readFile(packageJson), '$.version');
        bool revertIfAlreadyDeployed = vm.envOr('REVERT_IF_ALREADY_DEPLOYED', true);

        string memory outputJsonPath = vm.envOr(
            'DEPLOYMENT_ADDRESSES_JSON',
            string(abi.encodePacked('./deployments/deployment-v', version, '-', vm.toString(block.chainid), '.json'))
        );

        console2.log('Deploying all contracts with addresses:');
        console2.log('\tOwner:', ownerAddress);
        console2.log('\tGovernor:', governorAddress);

        console2.log('Version: ', version);

        // Load the deployment scripts
        DeployAccessManager deployAccessManager = new DeployAccessManager();
        DeployNVMConfig deployNVMConfig = new DeployNVMConfig();
        DeployLibraries deployLibraries = new DeployLibraries();
        DeployCoreContracts deployCoreContracts = new DeployCoreContracts();
        DeployNFTContracts deployNFTContracts = new DeployNFTContracts();
        DeployConditions deployConditions = new DeployConditions();
        DeployTemplates deployTemplates = new DeployTemplates();
        OwnerGrantRoles ownerGrantRoles = new OwnerGrantRoles();

        // Execute the deployments in order
        // 1. Deploy AccessManager
        AccessManager accessManager = deployAccessManager.run(
            ownerAddress, deploymentSalt[type(AccessManager).name].implementationSalt, revertIfAlreadyDeployed
        );

        // 2. Deploy NVMConfig
        NVMConfig nvmConfig = deployNVMConfig.run(
            ownerAddress, governorAddress, accessManager, deploymentSalt[type(NVMConfig).name], revertIfAlreadyDeployed
        );
        console2.log('NVMConfig deployed at:', address(nvmConfig));

        // 3. Deploy Libraries
        address tokenUtilsAddress =
            deployLibraries.run(ownerAddress, deploymentSalt[type(TokenUtils).name], revertIfAlreadyDeployed);
        console2.log('TokenUtils deployed at:', tokenUtilsAddress);

        // 4. Deploy Core Contracts
        (AssetsRegistry assetsRegistry, AgreementsStore agreementsStore, PaymentsVault paymentsVault) =
        deployCoreContracts.run(
            nvmConfig,
            accessManager,
            ownerAddress,
            deploymentSalt[type(AssetsRegistry).name],
            deploymentSalt[type(AgreementsStore).name],
            deploymentSalt[type(PaymentsVault).name],
            revertIfAlreadyDeployed
        );
        console2.log('AssetsRegistry deployed at:', address(assetsRegistry));
        console2.log('AgreementsStore deployed at:', address(agreementsStore));
        console2.log('PaymentsVault deployed at:', address(paymentsVault));

        // 5. Deploy NFT Contracts
        (NFT1155Credits nftCredits, NFT1155ExpirableCredits nftExpirableCredits) = deployNFTContracts.run(
            nvmConfig,
            accessManager,
            ownerAddress,
            assetsRegistry,
            deploymentSalt[type(NFT1155Credits).name],
            deploymentSalt[type(NFT1155ExpirableCredits).name],
            revertIfAlreadyDeployed
        );
        console2.log('NFT1155Credits deployed at:', address(nftCredits));
        console2.log('NFT1155ExpirableCredits deployed at:', address(nftExpirableCredits));

        // 6. Deploy Conditions
        (
            LockPaymentCondition lockPaymentCondition,
            TransferCreditsCondition transferCreditsCondition,
            DistributePaymentsCondition distributePaymentsCondition,
            FiatSettlementCondition fiatSettlementCondition
        ) = deployConditions.run(
            ownerAddress,
            nvmConfig,
            assetsRegistry,
            agreementsStore,
            paymentsVault,
            accessManager,
            deploymentSalt[type(LockPaymentCondition).name],
            deploymentSalt[type(TransferCreditsCondition).name],
            deploymentSalt[type(DistributePaymentsCondition).name],
            deploymentSalt[type(FiatSettlementCondition).name],
            revertIfAlreadyDeployed
        );
        console2.log('LockPaymentCondition deployed at:', address(lockPaymentCondition));
        console2.log('TransferCreditsCondition deployed at:', address(transferCreditsCondition));
        console2.log('DistributePaymentsCondition deployed at:', address(distributePaymentsCondition));
        console2.log('FiatSettlementCondition deployed at:', address(fiatSettlementCondition));

        // 7. Deploy Templates
        (FixedPaymentTemplate fixedPaymentTemplate, FiatPaymentTemplate fiatPaymentTemplate) = deployTemplates.run(
            ownerAddress,
            nvmConfig,
            assetsRegistry,
            agreementsStore,
            lockPaymentCondition,
            transferCreditsCondition,
            distributePaymentsCondition,
            fiatSettlementCondition,
            accessManager,
            deploymentSalt[type(FixedPaymentTemplate).name],
            deploymentSalt[type(FiatPaymentTemplate).name],
            revertIfAlreadyDeployed
        );
        console2.log('FixedPaymentTemplate deployed at:', address(fixedPaymentTemplate));
        console2.log('FiatPaymentTemplate deployed at:', address(fiatPaymentTemplate));

        // 8. Grant roles by Owner
        ownerGrantRoles.run(
            nvmConfig,
            ownerAddress,
            paymentsVault,
            nftCredits,
            lockPaymentCondition,
            transferCreditsCondition,
            distributePaymentsCondition,
            accessManager
        );
        console2.log('Roles granted successfully by Owner');

        // Build JSON with the deployment information
        string memory rootJsonKey = 'root';
        string memory jsonContent = vm.serializeString(rootJsonKey, 'version', version);
        jsonContent = vm.serializeAddress(rootJsonKey, 'owner', ownerAddress);
        jsonContent = vm.serializeAddress(rootJsonKey, 'governor', governorAddress);
        jsonContent = vm.serializeUint(rootJsonKey, 'chainId', block.chainid);
        jsonContent = vm.serializeUint(rootJsonKey, 'deployedAt', block.timestamp);

        // Start contracts object
        string memory contractJsonKey = 'contracts';
        string memory contractJsonContent = '';

        // Add each contract address
        contractJsonContent = vm.serializeAddress(contractJsonKey, type(AccessManager).name, address(accessManager));
        contractJsonContent = vm.serializeAddress(contractJsonKey, type(NVMConfig).name, address(nvmConfig));
        contractJsonContent = vm.serializeAddress(contractJsonKey, type(TokenUtils).name, tokenUtilsAddress);
        contractJsonContent = vm.serializeAddress(contractJsonKey, type(AssetsRegistry).name, address(assetsRegistry));
        contractJsonContent = vm.serializeAddress(contractJsonKey, type(AgreementsStore).name, address(agreementsStore));
        contractJsonContent = vm.serializeAddress(contractJsonKey, type(PaymentsVault).name, address(paymentsVault));
        contractJsonContent = vm.serializeAddress(contractJsonKey, type(NFT1155Credits).name, address(nftCredits));
        contractJsonContent =
            vm.serializeAddress(contractJsonKey, type(NFT1155ExpirableCredits).name, address(nftExpirableCredits));
        contractJsonContent =
            vm.serializeAddress(contractJsonKey, type(LockPaymentCondition).name, address(lockPaymentCondition));
        contractJsonContent =
            vm.serializeAddress(contractJsonKey, type(TransferCreditsCondition).name, address(transferCreditsCondition));
        contractJsonContent = vm.serializeAddress(
            contractJsonKey, type(DistributePaymentsCondition).name, address(distributePaymentsCondition)
        );
        contractJsonContent =
            vm.serializeAddress(contractJsonKey, type(FiatSettlementCondition).name, address(fiatSettlementCondition));
        contractJsonContent =
            vm.serializeAddress(contractJsonKey, type(FixedPaymentTemplate).name, address(fixedPaymentTemplate));
        contractJsonContent =
            vm.serializeAddress(contractJsonKey, type(FiatPaymentTemplate).name, address(fiatPaymentTemplate));

        // Combine all JSON parts
        jsonContent = vm.serializeString(rootJsonKey, contractJsonKey, contractJsonContent);

        vm.writeJson(jsonContent, outputJsonPath);
        console2.log('Deployment addresses written to %s', outputJsonPath);
    }
}
