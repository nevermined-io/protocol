// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../Constants.sol";
import {DeployConfig} from "./DeployConfig.sol";
import {INVMConfig} from "../../contracts/interfaces/INVMConfig.sol";
import {AssetsRegistry} from "../../contracts/AssetsRegistry.sol";
import {AgreementsStore} from "../../contracts/agreements/AgreementsStore.sol";
import {PaymentsVault} from "../../contracts/PaymentsVault.sol";

contract DeployCoreContracts is Script, DeployConfig {
    function run(address nvmConfigAddress) public returns (AssetsRegistry, AgreementsStore, PaymentsVault) {
        uint256 deployerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        uint256 governorPrivateKey = vm.envUint("GOVERNOR_PRIVATE_KEY");
        INVMConfig nvmConfig = INVMConfig(nvmConfigAddress);
        
        // Deploy AssetsRegistry
        vm.startBroadcast(deployerPrivateKey);
        AssetsRegistry assetsRegistry = new AssetsRegistry();
        assetsRegistry.initialize(nvmConfigAddress);
        vm.stopBroadcast();
        
        // Register AssetsRegistry in NVMConfig (called by governor)
        vm.startBroadcast(governorPrivateKey);
        nvmConfig.registerContract(Constants.HASH_ASSETS_REGISTRY, address(assetsRegistry), 1);
        vm.stopBroadcast();
        
        // Deploy AgreementsStore
        vm.startBroadcast(deployerPrivateKey);
        AgreementsStore agreementsStore = new AgreementsStore();
        agreementsStore.initialize(nvmConfigAddress);
        vm.stopBroadcast();
        
        // Register AgreementsStore in NVMConfig (called by governor)
        vm.startBroadcast(governorPrivateKey);
        nvmConfig.registerContract(Constants.HASH_AGREEMENTS_STORE, address(agreementsStore), 1);
        vm.stopBroadcast();
        
        // Deploy PaymentsVault
        vm.startBroadcast(deployerPrivateKey);
        PaymentsVault paymentsVault = new PaymentsVault();
        paymentsVault.initialize(nvmConfigAddress);
        vm.stopBroadcast();
        
        // Register PaymentsVault in NVMConfig (called by governor)
        vm.startBroadcast(governorPrivateKey);
        nvmConfig.registerContract(Constants.HASH_PAYMENTS_VAULT, address(paymentsVault), 1);
        vm.stopBroadcast();
        
        return (assetsRegistry, agreementsStore, paymentsVault);
    }
}
