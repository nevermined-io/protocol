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

struct DeployedContracts {
    AccessManager accessManager;
    NVMConfig nvmConfig;
    address tokenUtils;
    AssetsRegistry assetsRegistry;
    AgreementsStore agreementsStore;
    PaymentsVault paymentsVault;
    NFT1155Credits nftCredits;
    NFT1155ExpirableCredits nftExpirableCredits;
    LockPaymentCondition lockPaymentCondition;
    TransferCreditsCondition transferCreditsCondition;
    DistributePaymentsCondition distributePaymentsCondition;
    FiatSettlementCondition fiatSettlementCondition;
    FixedPaymentTemplate fixedPaymentTemplate;
    FiatPaymentTemplate fiatPaymentTemplate;
}

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

    function run() public returns (DeployedContracts memory deployed) {
        bool debug = vm.envOr('DEBUG', false);
        address ownerAddress = vm.envOr('OWNER_ADDRESS', msg.sender);
        address governorAddress = vm.envOr('GOVERNOR_ADDRESS', msg.sender);

        string memory packageJson = vm.envOr('PACKAGE_JSON', string('./package.json'));
        string memory version = vm.parseJsonString(vm.readFile(packageJson), '$.version');
        bool revertIfAlreadyDeployed = vm.envOr('REVERT_IF_ALREADY_DEPLOYED', true);

        string memory outputJsonPath = vm.envOr(
            'DEPLOYMENT_ADDRESSES_JSON',
            string(abi.encodePacked('./deployments/deployment-v', version, '-', vm.toString(block.chainid), '.json'))
        );

        if (debug) {
            console2.log('Deploying all contracts with addresses:');
            console2.log('\tOwner:', ownerAddress);
            console2.log('\tGovernor:', governorAddress);
            console2.log('Version: ', version);
        }
        
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
        deployed.accessManager = deployAccessManager.run(
            ownerAddress, deploymentSalt[type(AccessManager).name].implementationSalt, revertIfAlreadyDeployed
        );

        // 2. Deploy NVMConfig
        deployed.nvmConfig = deployNVMConfig.run(
            ownerAddress,
            governorAddress,
            deployed.accessManager,
            deploymentSalt[type(NVMConfig).name],
            revertIfAlreadyDeployed
        );
        if (debug) console2.log('NVMConfig deployed at:', address(deployed.nvmConfig));

        // 3. Deploy Libraries
        deployed.tokenUtils =
            deployLibraries.run(ownerAddress, deploymentSalt[type(TokenUtils).name], revertIfAlreadyDeployed);
        if (debug) console2.log('TokenUtils deployed at:', deployed.tokenUtils);

        // 4. Deploy Core Contracts
        (deployed.assetsRegistry, deployed.agreementsStore, deployed.paymentsVault) = deployCoreContracts.run(
            deployed.nvmConfig,
            deployed.accessManager,
            ownerAddress,
            deploymentSalt[type(AssetsRegistry).name],
            deploymentSalt[type(AgreementsStore).name],
            deploymentSalt[type(PaymentsVault).name],
            revertIfAlreadyDeployed
        );
        if (debug) {
            console2.log('AssetsRegistry deployed at:', address(deployed.assetsRegistry));
            console2.log('AgreementsStore deployed at:', address(deployed.agreementsStore));
            console2.log('PaymentsVault deployed at:', address(deployed.paymentsVault));
        }
        // 5. Deploy NFT Contracts
        (deployed.nftCredits, deployed.nftExpirableCredits) = deployNFTContracts.run(
            deployed.nvmConfig,
            deployed.accessManager,
            ownerAddress,
            deployed.assetsRegistry,
            deploymentSalt[type(NFT1155Credits).name],
            deploymentSalt[type(NFT1155ExpirableCredits).name],
            revertIfAlreadyDeployed
        );
        if (debug) console2.log('NFT1155Credits deployed at:', address(deployed.nftCredits));
        if (debug) console2.log('NFT1155ExpirableCredits deployed at:', address(deployed.nftExpirableCredits));

        // 6. Deploy Conditions
        (
            deployed.lockPaymentCondition,
            deployed.transferCreditsCondition,
            deployed.distributePaymentsCondition,
            deployed.fiatSettlementCondition
        ) = deployConditions.run(
            ownerAddress,
            deployed.nvmConfig,
            deployed.assetsRegistry,
            deployed.agreementsStore,
            deployed.paymentsVault,
            deployed.accessManager,
            deploymentSalt[type(LockPaymentCondition).name],
            deploymentSalt[type(TransferCreditsCondition).name],
            deploymentSalt[type(DistributePaymentsCondition).name],
            deploymentSalt[type(FiatSettlementCondition).name],
            revertIfAlreadyDeployed
        );
        if (debug) {
            console2.log('LockPaymentCondition deployed at:', address(deployed.lockPaymentCondition));
            console2.log('TransferCreditsCondition deployed at:', address(deployed.transferCreditsCondition));
            console2.log('DistributePaymentsCondition deployed at:', address(deployed.distributePaymentsCondition));
            console2.log('FiatSettlementCondition deployed at:', address(deployed.fiatSettlementCondition));
        }

        // 7. Deploy Templates
        (deployed.fixedPaymentTemplate, deployed.fiatPaymentTemplate) = deployTemplates.run(
            ownerAddress,
            deployed.nvmConfig,
            deployed.assetsRegistry,
            deployed.agreementsStore,
            deployed.lockPaymentCondition,
            deployed.transferCreditsCondition,
            deployed.distributePaymentsCondition,
            deployed.fiatSettlementCondition,
            deployed.accessManager,
            deploymentSalt[type(FixedPaymentTemplate).name],
            deploymentSalt[type(FiatPaymentTemplate).name],
            revertIfAlreadyDeployed
        );
        if (debug) console2.log('FixedPaymentTemplate deployed at:', address(deployed.fixedPaymentTemplate));
        if (debug) console2.log('FiatPaymentTemplate deployed at:', address(deployed.fiatPaymentTemplate));

        // 8. Grant roles by Owner
        ownerGrantRoles.run(
            deployed.nvmConfig,
            ownerAddress,
            deployed.paymentsVault,
            deployed.nftCredits,
            deployed.lockPaymentCondition,
            deployed.transferCreditsCondition,
            deployed.distributePaymentsCondition,
            deployed.accessManager
        );
        if (debug) console2.log('Roles granted successfully by Owner');

        // Build JSON with the deployment information
        string memory rootJsonKey = 'root';
        string memory jsonContent = vm.serializeString(rootJsonKey, 'version', version);
        jsonContent = vm.serializeAddress(rootJsonKey, 'owner', ownerAddress);
        jsonContent = vm.serializeAddress(rootJsonKey, 'governor', governorAddress);
        jsonContent = vm.serializeUint(rootJsonKey, 'chainId', block.chainid);
        jsonContent = vm.serializeUint(rootJsonKey, 'blockNumber', block.number);
        jsonContent = vm.serializeUint(rootJsonKey, 'snapshotId', 0);
        jsonContent = vm.serializeUint(rootJsonKey, 'deployedAt', block.timestamp);

        // Start contracts object
        string memory contractJsonKey = 'contracts';
        string memory contractJsonContent = '';

        // Add each contract address
        contractJsonContent =
            vm.serializeAddress(contractJsonKey, type(AccessManager).name, address(deployed.accessManager));
        contractJsonContent = vm.serializeAddress(contractJsonKey, type(NVMConfig).name, address(deployed.nvmConfig));
        contractJsonContent = vm.serializeAddress(contractJsonKey, type(TokenUtils).name, deployed.tokenUtils);
        contractJsonContent =
            vm.serializeAddress(contractJsonKey, type(AssetsRegistry).name, address(deployed.assetsRegistry));
        contractJsonContent =
            vm.serializeAddress(contractJsonKey, type(AgreementsStore).name, address(deployed.agreementsStore));
        contractJsonContent =
            vm.serializeAddress(contractJsonKey, type(PaymentsVault).name, address(deployed.paymentsVault));
        contractJsonContent =
            vm.serializeAddress(contractJsonKey, type(NFT1155Credits).name, address(deployed.nftCredits));
        contractJsonContent = vm.serializeAddress(
            contractJsonKey, type(NFT1155ExpirableCredits).name, address(deployed.nftExpirableCredits)
        );
        contractJsonContent = vm.serializeAddress(
            contractJsonKey, type(LockPaymentCondition).name, address(deployed.lockPaymentCondition)
        );
        contractJsonContent = vm.serializeAddress(
            contractJsonKey, type(TransferCreditsCondition).name, address(deployed.transferCreditsCondition)
        );
        contractJsonContent = vm.serializeAddress(
            contractJsonKey, type(DistributePaymentsCondition).name, address(deployed.distributePaymentsCondition)
        );
        contractJsonContent = vm.serializeAddress(
            contractJsonKey, type(FiatSettlementCondition).name, address(deployed.fiatSettlementCondition)
        );
        contractJsonContent = vm.serializeAddress(
            contractJsonKey, type(FixedPaymentTemplate).name, address(deployed.fixedPaymentTemplate)
        );
        contractJsonContent =
            vm.serializeAddress(contractJsonKey, type(FiatPaymentTemplate).name, address(deployed.fiatPaymentTemplate));

        // Combine all JSON parts
        jsonContent = vm.serializeString(rootJsonKey, contractJsonKey, contractJsonContent);

        vm.writeJson(jsonContent, outputJsonPath);
        if (debug) console2.log('Deployment addresses written to %s', outputJsonPath);
    }
}
