// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {AssetsRegistry} from '../../contracts/AssetsRegistry.sol';

import {PaymentsVault} from '../../contracts/PaymentsVault.sol';
import {AgreementsStore} from '../../contracts/agreements/AgreementsStore.sol';
import {DeployConfig} from './DeployConfig.sol';

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract DeployCoreContracts is Script, DeployConfig {
    function run(address nvmConfigAddress, address accessManagerAddress, address ownerAddress)
        public
        returns (AssetsRegistry, AgreementsStore, PaymentsVault)
    {
        console2.log('Deploying Core Contracts with:');
        console2.log('\tNVMConfig:', nvmConfigAddress);
        console2.log('\tAccessManager:', accessManagerAddress);
        console2.log('\tOwner:', ownerAddress);

        vm.startBroadcast(ownerAddress);

        // Deploy AssetsRegistry
        AssetsRegistry assetsRegistryImpl = new AssetsRegistry();
        bytes memory assetsRegistryData =
            abi.encodeCall(AssetsRegistry.initialize, (nvmConfigAddress, accessManagerAddress));
        AssetsRegistry assetsRegistry =
            AssetsRegistry(address(new ERC1967Proxy(address(assetsRegistryImpl), assetsRegistryData)));

        // Deploy AgreementsStore
        AgreementsStore agreementsStoreImpl = new AgreementsStore();
        bytes memory agreementsStoreData =
            abi.encodeCall(AgreementsStore.initialize, (nvmConfigAddress, accessManagerAddress));
        AgreementsStore agreementsStore =
            AgreementsStore(address(new ERC1967Proxy(address(agreementsStoreImpl), agreementsStoreData)));

        // Deploy PaymentsVault
        PaymentsVault paymentsVaultImpl = new PaymentsVault();
        bytes memory paymentsVaultData =
            abi.encodeCall(PaymentsVault.initialize, (nvmConfigAddress, accessManagerAddress));
        PaymentsVault paymentsVault =
            PaymentsVault(payable(address(new ERC1967Proxy(address(paymentsVaultImpl), paymentsVaultData))));

        vm.stopBroadcast();

        return (assetsRegistry, agreementsStore, paymentsVault);
    }
}
