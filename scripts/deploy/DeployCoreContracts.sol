// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {AssetsRegistry} from '../../contracts/AssetsRegistry.sol';
import {PaymentsVault} from '../../contracts/PaymentsVault.sol';
import {AgreementsStore} from '../../contracts/agreements/AgreementsStore.sol';

import {PaymentsVault} from '../../contracts/PaymentsVault.sol';
import {INVMConfig} from '../../contracts/interfaces/INVMConfig.sol';
import {DeployConfig} from './DeployConfig.sol';

import {Create2DeployUtils} from './common/Create2DeployUtils.sol';
import {UpgradeableContractDeploySalt} from './common/Types.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';
import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract DeployCoreContracts is Script, DeployConfig, Create2DeployUtils {
    error AccessManagerDeployment_InvalidAuthority(address authority);
    error AssetRegistryDeployment_InvalidAuthority(address authority);
    error AgreementsStoreDeployment_InvalidAuthority(address authority);
    error PaymentsVaultDeployment_InvalidAuthority(address authority);
    error InvalidSalt();

    function run(
        INVMConfig nvmConfigAddress,
        IAccessManager accessManagerAddress,
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

        console2.log('Deploying Core Contracts with:');
        console2.log('\tNVMConfig:', address(nvmConfigAddress));
        console2.log('\tAccessManager:', address(accessManagerAddress));
        console2.log('\tOwner:', ownerAddress);

        vm.startBroadcast(ownerAddress);

        // Deploy AssetsRegistry
        assetsRegistry =
            deployAssetsRegistry(nvmConfigAddress, accessManagerAddress, assetsRegistrySalt, revertIfAlreadyDeployed);

        // Deploy AgreementsStore
        agreementsStore =
            deployAgreementsStore(nvmConfigAddress, accessManagerAddress, agreementsStoreSalt, revertIfAlreadyDeployed);

        // Deploy PaymentsVault
        paymentsVault =
            deployPaymentsVault(nvmConfigAddress, accessManagerAddress, paymentsVaultSalt, revertIfAlreadyDeployed);

        vm.stopBroadcast();

        return (assetsRegistry, agreementsStore, paymentsVault);
    }

    function deployAssetsRegistry(
        INVMConfig nvmConfigAddress,
        IAccessManager accessManagerAddress,
        UpgradeableContractDeploySalt memory assetsRegistrySalt,
        bool revertIfAlreadyDeployed
    ) public returns (AssetsRegistry assetsRegistry) {
        // Check for zero salt
        require(assetsRegistrySalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy AssetsRegistry Implementation
        console2.log('Deploying AssetsRegistry Implementation');
        (address assetsRegistryImpl,) = deployWithSanityChecks(
            assetsRegistrySalt.implementationSalt, type(AssetsRegistry).creationCode, revertIfAlreadyDeployed
        );
        console2.log('AssetsRegistry Implementation deployed at:', address(assetsRegistryImpl));

        // Deploy AssetsRegistry Proxy
        console2.log('Deploying AssetsRegistry Proxy');
        bytes memory assetsRegistryInitData =
            abi.encodeCall(AssetsRegistry.initialize, (nvmConfigAddress, accessManagerAddress));
        (address assetsRegistryProxy,) = deployWithSanityChecks(
            assetsRegistrySalt.proxySalt,
            getERC1967ProxyCreationCode(abi.encodePacked(address(assetsRegistryImpl), assetsRegistryInitData)),
            revertIfAlreadyDeployed
        );
        assetsRegistry = AssetsRegistry(assetsRegistryProxy);
        console2.log('AssetsRegistry Proxy deployed at:', address(assetsRegistry));

        // Verify deployment
        require(
            assetsRegistry.authority() == address(accessManagerAddress),
            AssetRegistryDeployment_InvalidAuthority(address(assetsRegistry.authority()))
        );
    }

    function deployAgreementsStore(
        INVMConfig nvmConfigAddress,
        IAccessManager accessManagerAddress,
        UpgradeableContractDeploySalt memory agreementsStoreSalt,
        bool revertIfAlreadyDeployed
    ) public returns (AgreementsStore agreementsStore) {
        // Check for zero salt
        require(agreementsStoreSalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy Agreements Store Implementation
        console2.log('Deploying AgreementsStore Implementation');
        (address agreementsStoreImpl,) = deployWithSanityChecks(
            agreementsStoreSalt.implementationSalt, type(AgreementsStore).creationCode, revertIfAlreadyDeployed
        );
        console2.log('AgreementsStore Implementation deployed at:', address(agreementsStoreImpl));

        // Deploy Agreements Store Proxy
        console2.log('Deploying AgreementsStore Proxy');
        bytes memory agreementsStoreInitData =
            abi.encodeCall(AgreementsStore.initialize, (nvmConfigAddress, accessManagerAddress));
        (address agreementsStoreProxy,) = deployWithSanityChecks(
            agreementsStoreSalt.proxySalt,
            getERC1967ProxyCreationCode(abi.encodePacked(address(agreementsStoreImpl), agreementsStoreInitData)),
            revertIfAlreadyDeployed
        );
        agreementsStore = AgreementsStore(agreementsStoreProxy);
        console2.log('AgreementsStore Proxy deployed at:', address(agreementsStore));

        // Verify deployment
        require(
            agreementsStore.authority() == address(accessManagerAddress),
            AgreementsStoreDeployment_InvalidAuthority(address(agreementsStore.authority()))
        );
    }

    function deployPaymentsVault(
        INVMConfig nvmConfigAddress,
        IAccessManager accessManagerAddress,
        UpgradeableContractDeploySalt memory paymentsVaultSalt,
        bool revertIfAlreadyDeployed
    ) public returns (PaymentsVault paymentsVault) {
        // Check for zero salt
        require(paymentsVaultSalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy PaymentsVault Implementation
        console2.log('Deploying PaymentsVault Implementation');
        (address paymentsVaultImpl,) = deployWithSanityChecks(
            paymentsVaultSalt.implementationSalt, type(PaymentsVault).creationCode, revertIfAlreadyDeployed
        );
        console2.log('PaymentsVault Implementation deployed at:', address(paymentsVaultImpl));

        // Deploy PaymentsVault Proxy
        console2.log('Deploying PaymentsVault Proxy');
        bytes memory paymentsVaultInitData =
            abi.encodeCall(PaymentsVault.initialize, (nvmConfigAddress, accessManagerAddress));
        (address paymentsVaultProxy,) = deployWithSanityChecks(
            paymentsVaultSalt.proxySalt,
            getERC1967ProxyCreationCode(abi.encodePacked(address(paymentsVaultImpl), paymentsVaultInitData)),
            revertIfAlreadyDeployed
        );
        paymentsVault = PaymentsVault(payable(paymentsVaultProxy));
        console2.log('PaymentsVault Proxy deployed at:', address(paymentsVault));

        // Verify Deployment
        require(
            paymentsVault.authority() == address(accessManagerAddress),
            PaymentsVaultDeployment_InvalidAuthority(address(paymentsVault.authority()))
        );
    }
}
