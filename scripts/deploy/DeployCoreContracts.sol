// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import {AssetsRegistry} from '../../contracts/AssetsRegistry.sol';
import {PaymentsVault} from '../../contracts/PaymentsVault.sol';
import {AgreementsStore} from '../../contracts/agreements/AgreementsStore.sol';
import {IFeeController} from '../../contracts/interfaces/IFeeController.sol';

import {PaymentsVault} from '../../contracts/PaymentsVault.sol';
import {INVMConfig} from '../../contracts/interfaces/INVMConfig.sol';
import {DeployConfig} from './DeployConfig.sol';

import {Create2DeployUtils} from './common/Create2DeployUtils.sol';
import {UpgradeableContractDeploySalt} from './common/Types.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';
import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {Script} from 'lib/forge-std/src/Script.sol';
import {console2} from 'lib/forge-std/src/console2.sol';

contract DeployCoreContracts is DeployConfig, Create2DeployUtils {
    error AccessManagerDeployment_InvalidAuthority(address authority);
    error AssetRegistryDeployment_InvalidAuthority(address authority);
    error AgreementsStoreDeployment_InvalidAuthority(address authority);
    error PaymentsVaultDeployment_InvalidAuthority(address authority);
    error InvalidSalt();

    function run(
        INVMConfig nvmConfigAddress,
        IAccessManager accessManagerAddress,
        IFeeController feeControllerAddress,
        address ownerAddress,
        UpgradeableContractDeploySalt memory assetsRegistrySalt,
        UpgradeableContractDeploySalt memory agreementsStoreSalt,
        UpgradeableContractDeploySalt memory paymentsVaultSalt,
        bool revertIfAlreadyDeployed
    ) public returns (AssetsRegistry assetsRegistry, AgreementsStore agreementsStore, PaymentsVault paymentsVault) {
        // Check for zero salts
        require(
            assetsRegistrySalt.implementationSalt != bytes32(0) && agreementsStoreSalt.implementationSalt != bytes32(0)
                && paymentsVaultSalt.implementationSalt != bytes32(0),
            InvalidSalt()
        );

        if (debug) {
            console2.log('Deploying Core Contracts with:');
            console2.log('\tNVMConfig:', address(nvmConfigAddress));
            console2.log('\tAccessManager:', address(accessManagerAddress));
            console2.log('\tOwner:', ownerAddress);
        }

        vm.startBroadcast(ownerAddress);

        // Deploy AssetsRegistry
        assetsRegistry = deployAssetsRegistry(
            nvmConfigAddress, accessManagerAddress, feeControllerAddress, assetsRegistrySalt, revertIfAlreadyDeployed
        );

        // Deploy AgreementsStore
        agreementsStore = deployAgreementsStore(accessManagerAddress, agreementsStoreSalt, revertIfAlreadyDeployed);

        // Deploy PaymentsVault
        paymentsVault = deployPaymentsVault(accessManagerAddress, paymentsVaultSalt, revertIfAlreadyDeployed);

        vm.stopBroadcast();

        return (assetsRegistry, agreementsStore, paymentsVault);
    }

    function deployAssetsRegistry(
        INVMConfig nvmConfigAddress,
        IAccessManager accessManagerAddress,
        IFeeController feeControllerAddress,
        UpgradeableContractDeploySalt memory assetsRegistrySalt,
        bool revertIfAlreadyDeployed
    ) public returns (AssetsRegistry assetsRegistry) {
        // Check for zero salt
        require(assetsRegistrySalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy AssetsRegistry Implementation
        if (debug) console2.log('Deploying AssetsRegistry Implementation');
        (address assetsRegistryImpl,) = deployWithSanityChecks(
            assetsRegistrySalt.implementationSalt, type(AssetsRegistry).creationCode, revertIfAlreadyDeployed
        );
        if (debug) console2.log('AssetsRegistry Implementation deployed at:', address(assetsRegistryImpl));

        // Deploy AssetsRegistry Proxy
        if (debug) console2.log('Deploying AssetsRegistry Proxy');
        bytes memory assetsRegistryInitData =
            abi.encodeCall(AssetsRegistry.initialize, (nvmConfigAddress, accessManagerAddress, feeControllerAddress));
        (address assetsRegistryProxy,) = deployWithSanityChecks(
            assetsRegistrySalt.proxySalt,
            getERC1967ProxyCreationCode(address(assetsRegistryImpl), assetsRegistryInitData),
            revertIfAlreadyDeployed
        );
        assetsRegistry = AssetsRegistry(assetsRegistryProxy);
        if (debug) console2.log('AssetsRegistry Proxy deployed at:', address(assetsRegistry));

        // Verify deployment
        require(
            assetsRegistry.authority() == address(accessManagerAddress),
            AssetRegistryDeployment_InvalidAuthority(address(assetsRegistry.authority()))
        );
    }

    function deployAgreementsStore(
        IAccessManager accessManagerAddress,
        UpgradeableContractDeploySalt memory agreementsStoreSalt,
        bool revertIfAlreadyDeployed
    ) public returns (AgreementsStore agreementsStore) {
        // Check for zero salt
        require(agreementsStoreSalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy Agreements Store Implementation
        if (debug) console2.log('Deploying AgreementsStore Implementation');
        (address agreementsStoreImpl,) = deployWithSanityChecks(
            agreementsStoreSalt.implementationSalt, type(AgreementsStore).creationCode, revertIfAlreadyDeployed
        );
        if (debug) console2.log('AgreementsStore Implementation deployed at:', address(agreementsStoreImpl));

        // Deploy Agreements Store Proxy
        if (debug) console2.log('Deploying AgreementsStore Proxy');
        bytes memory agreementsStoreInitData = abi.encodeCall(AgreementsStore.initialize, (accessManagerAddress));
        (address agreementsStoreProxy,) = deployWithSanityChecks(
            agreementsStoreSalt.proxySalt,
            getERC1967ProxyCreationCode(address(agreementsStoreImpl), agreementsStoreInitData),
            revertIfAlreadyDeployed
        );
        agreementsStore = AgreementsStore(agreementsStoreProxy);
        if (debug) console2.log('AgreementsStore Proxy deployed at:', address(agreementsStore));

        // Verify deployment
        require(
            agreementsStore.authority() == address(accessManagerAddress),
            AgreementsStoreDeployment_InvalidAuthority(address(agreementsStore.authority()))
        );
    }

    function deployPaymentsVault(
        IAccessManager accessManagerAddress,
        UpgradeableContractDeploySalt memory paymentsVaultSalt,
        bool revertIfAlreadyDeployed
    ) public returns (PaymentsVault paymentsVault) {
        // Check for zero salt
        require(paymentsVaultSalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy PaymentsVault Implementation
        if (debug) console2.log('Deploying PaymentsVault Implementation');
        (address paymentsVaultImpl,) = deployWithSanityChecks(
            paymentsVaultSalt.implementationSalt, type(PaymentsVault).creationCode, revertIfAlreadyDeployed
        );
        if (debug) console2.log('PaymentsVault Implementation deployed at:', address(paymentsVaultImpl));

        // Deploy PaymentsVault Proxy
        if (debug) console2.log('Deploying PaymentsVault Proxy');
        bytes memory paymentsVaultInitData = abi.encodeCall(PaymentsVault.initialize, (accessManagerAddress));
        (address paymentsVaultProxy,) = deployWithSanityChecks(
            paymentsVaultSalt.proxySalt,
            getERC1967ProxyCreationCode(address(paymentsVaultImpl), paymentsVaultInitData),
            revertIfAlreadyDeployed
        );
        paymentsVault = PaymentsVault(payable(paymentsVaultProxy));
        if (debug) console2.log('PaymentsVault Proxy deployed at:', address(paymentsVault));

        // Verify Deployment
        require(
            paymentsVault.authority() == address(accessManagerAddress),
            PaymentsVaultDeployment_InvalidAuthority(address(paymentsVault.authority()))
        );
    }
}
