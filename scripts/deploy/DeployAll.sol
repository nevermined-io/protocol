// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

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

import {DeployFeeContracts} from './DeployFeeContracts.sol';
import {DeployLibraries} from './DeployLibraries.sol';
import {DeployNFTContracts} from './DeployNFTContracts.sol';
import {DeployNVMConfig} from './DeployNVMConfig.sol';
import {DeployTemplates} from './DeployTemplates.sol';

import {ProtocolStandardFees} from '../../contracts/fees/ProtocolStandardFees.sol';
import {UpgradeableContractDeploySalt} from './common/Types.sol';
import {AccessManager} from '@openzeppelin/contracts/access/manager/AccessManager.sol';

import {Script} from 'lib/forge-std/src/Script.sol';
import {console2} from 'lib/forge-std/src/console2.sol';

import {OneTimeCreatorHook} from '../../contracts/hooks/OneTimeCreatorHook.sol';
import {DeployHooks} from './DeployHooks.sol';

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
    OneTimeCreatorHook oneTimeCreatorHook;
    ProtocolStandardFees protocolStandardFees;
}

contract DeployAll is Script, DeployConfig {
    mapping(string contractName => UpgradeableContractDeploySalt implementationSalt) public deploymentSalt;

    constructor() {
        //// Set the deployment salts ////
        string memory version = vm.envString('CONTRACTS_DEPLOYMENT_VERSION');
        console2.log('Contracts deployment version:', version);

        // AccessManager
        deploymentSalt[type(AccessManager).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('ACCESS_MANAGER_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('ACCESS_MANAGER_PROXY_', version))
        });

        // OneTimeCreatorHook
        deploymentSalt[type(OneTimeCreatorHook).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('ONE_TIME_CREATOR_HOOK_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('ONE_TIME_CREATOR_HOOK_PROXY_', version))
        });

        // NVMConfig
        deploymentSalt[type(NVMConfig).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('NVM_CONFIG_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('NVM_CONFIG_PROXY_', version))
        });

        // TokenUtils
        deploymentSalt[type(TokenUtils).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('TOKEN_UTILS_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('TOKEN_UTILS_PROXY_', version))
        });

        // Core Contracts
        deploymentSalt[type(AssetsRegistry).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('ASSETS_REGISTRY_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('ASSETS_REGISTRY_PROXY_', version))
        });

        deploymentSalt[type(AgreementsStore).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('AGREEMENTS_STORE_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('AGREEMENTS_STORE_PROXY_', version))
        });

        deploymentSalt[type(PaymentsVault).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('PAYMENTS_VAULT_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('PAYMENTS_VAULT_PROXY_', version))
        });

        // NFT Contracts
        deploymentSalt[type(NFT1155Credits).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('NFT1155_CREDITS_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('NFT1155_CREDITS_PROXY_', version))
        });

        deploymentSalt[type(NFT1155ExpirableCredits).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('NFT1155_EXPIRABLE_CREDITS_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('NFT1155_EXPIRABLE_CREDITS_PROXY_', version))
        });

        // Conditions
        deploymentSalt[type(LockPaymentCondition).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('LOCK_PAYMENT_CONDITION_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('LOCK_PAYMENT_CONDITION_PROXY_', version))
        });

        deploymentSalt[type(TransferCreditsCondition).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('TRANSFER_CREDITS_CONDITION_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('TRANSFER_CREDITS_CONDITION_PROXY_', version))
        });

        deploymentSalt[type(DistributePaymentsCondition).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('DISTRIBUTE_PAYMENTS_CONDITION_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('DISTRIBUTE_PAYMENTS_CONDITION_PROXY_', version))
        });

        deploymentSalt[type(FiatSettlementCondition).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('FIAT_SETTLEMENT_CONDITION_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('FIAT_SETTLEMENT_CONDITION_PROXY_', version))
        });

        // Templates
        deploymentSalt[type(FixedPaymentTemplate).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('FIXED_PAYMENT_TEMPLATE_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('FIXED_PAYMENT_TEMPLATE_PROXY_', version))
        });

        deploymentSalt[type(FiatPaymentTemplate).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('FIAT_PAYMENT_TEMPLATE_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('FIAT_PAYMENT_TEMPLATE_PROXY_', version))
        });

        // Fees
        deploymentSalt[type(ProtocolStandardFees).name] = UpgradeableContractDeploySalt({
            implementationSalt: keccak256(abi.encodePacked('PROTOCOL_STANDARD_FEES_IMPL_', version)),
            proxySalt: keccak256(abi.encodePacked('PROTOCOL_STANDARD_FEES_PROXY_', version))
        });
    }

    function run() public returns (DeployedContracts memory deployed) {
        bool debug = vm.envOr('DEBUG', false);
        address ownerAddress = vm.envOr('OWNER_ADDRESS', msg.sender);
        address governorAddress = vm.envOr('GOVERNOR_ADDRESS', msg.sender);
        address upgraderAddress = vm.envOr('UPGRADER_ADDRESS', msg.sender);

        bool revertIfAlreadyDeployed = vm.envOr('REVERT_IF_ALREADY_DEPLOYED', true);

        if (debug) {
            console2.log('Deploying all contracts with addresses:');
            console2.log('\tOwner:', ownerAddress);
            console2.log('\tGovernor:', governorAddress);
        }

        // Execute the deployments in order
        // 1. Deploy AccessManager
        deployed.accessManager = new DeployAccessManager().run(
            ownerAddress, deploymentSalt[type(AccessManager).name].implementationSalt, revertIfAlreadyDeployed
        );

        // Deploy OneTimeCreatorHook using DeployHooks
        deployed.oneTimeCreatorHook = new DeployHooks().run(
            DeployHooks.DeployHooksParams({
                ownerAddress: ownerAddress,
                accessManagerAddress: deployed.accessManager,
                oneTimeCreatorHookSalt: deploymentSalt[type(OneTimeCreatorHook).name],
                revertIfAlreadyDeployed: revertIfAlreadyDeployed
            })
        );
        if (debug) console2.log('OneTimeCreatorHook deployed at:', address(deployed.oneTimeCreatorHook));

        // Deploy Fees
        deployed.protocolStandardFees = new DeployFeeContracts().run(
            DeployFeeContracts.DeployFeeContractsParams({
                ownerAddress: ownerAddress,
                accessManagerAddress: deployed.accessManager,
                protocolStandardFeesSalt: deploymentSalt[type(ProtocolStandardFees).name],
                revertIfAlreadyDeployed: revertIfAlreadyDeployed
            })
        );
        if (debug) console2.log('ProtocolStandardFees deployed at:', address(deployed.protocolStandardFees));

        // 2. Deploy NVMConfig
        deployed.nvmConfig = new DeployNVMConfig().run(
            ownerAddress,
            deployed.accessManager,
            deployed.protocolStandardFees,
            deploymentSalt[type(NVMConfig).name],
            revertIfAlreadyDeployed
        );
        if (debug) console2.log('NVMConfig deployed at:', address(deployed.nvmConfig));

        // 3. Deploy Libraries
        deployed.tokenUtils =
            new DeployLibraries().run(ownerAddress, deploymentSalt[type(TokenUtils).name], revertIfAlreadyDeployed);
        if (debug) console2.log('TokenUtils deployed at:', deployed.tokenUtils);

        // 4. Deploy Core Contracts
        (deployed.assetsRegistry, deployed.agreementsStore, deployed.paymentsVault) = new DeployCoreContracts().run(
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
        (deployed.nftCredits, deployed.nftExpirableCredits) = new DeployNFTContracts().run(
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
        ) = new DeployConditions().run(
            ownerAddress,
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
        (deployed.fixedPaymentTemplate, deployed.fiatPaymentTemplate) = new DeployTemplates().run(
            DeployTemplates.DeployTemplatesParams({
                ownerAddress: ownerAddress,
                nvmConfigAddress: deployed.nvmConfig,
                assetsRegistryAddress: deployed.assetsRegistry,
                agreementsStoreAddress: deployed.agreementsStore,
                lockPaymentConditionAddress: deployed.lockPaymentCondition,
                transferCreditsConditionAddress: deployed.transferCreditsCondition,
                distributePaymentsConditionAddress: deployed.distributePaymentsCondition,
                fiatSettlementConditionAddress: deployed.fiatSettlementCondition,
                accessManagerAddress: deployed.accessManager,
                fixedPaymentTemplateSalt: deploymentSalt[type(FixedPaymentTemplate).name],
                fiatPaymentTemplateSalt: deploymentSalt[type(FiatPaymentTemplate).name],
                revertIfAlreadyDeployed: revertIfAlreadyDeployed
            })
        );
        if (debug) console2.log('FixedPaymentTemplate deployed at:', address(deployed.fixedPaymentTemplate));
        if (debug) console2.log('FiatPaymentTemplate deployed at:', address(deployed.fiatPaymentTemplate));

        // Build JSON with the deployment information
        string memory packageJson = vm.envOr('PACKAGE_JSON', string('./package.json'));
        string memory version = vm.parseJsonString(vm.readFile(packageJson), '$.version');
        string memory outputJsonPath = vm.envOr(
            'DEPLOYMENT_ADDRESSES_JSON',
            string(abi.encodePacked('./deployments/deployment-v', version, '-', vm.toString(block.chainid), '.json'))
        );

        string memory rootJsonKey = 'root';
        string memory jsonContent = vm.serializeString(rootJsonKey, 'version', version);
        jsonContent = vm.serializeAddress(rootJsonKey, 'owner', ownerAddress);
        jsonContent = vm.serializeAddress(rootJsonKey, 'governor', governorAddress);
        jsonContent = vm.serializeAddress(rootJsonKey, 'upgrader', upgraderAddress);
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
        contractJsonContent =
            vm.serializeAddress(contractJsonKey, type(OneTimeCreatorHook).name, address(deployed.oneTimeCreatorHook));
        contractJsonContent = vm.serializeAddress(
            contractJsonKey, type(ProtocolStandardFees).name, address(deployed.protocolStandardFees)
        );

        // Combine all JSON parts
        jsonContent = vm.serializeString(rootJsonKey, contractJsonKey, contractJsonContent);

        vm.writeJson(jsonContent, outputJsonPath);
        if (debug) console2.log('Deployment addresses written to %s', outputJsonPath);
    }
}
