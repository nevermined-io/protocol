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
        // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
        vm.startBroadcast();
        
        // Get the current sender address to use as owner
        owner = msg.sender;
        
        // For governor operations, you would need to run a separate command with the governor index
        // This script assumes the owner is deploying the contracts
        INVMConfig nvmConfig = INVMConfig(nvmConfigAddress);
        
        // Deploy AssetsRegistry
        AssetsRegistry assetsRegistry = new AssetsRegistry();
        assetsRegistry.initialize(nvmConfigAddress);
        
        // Deploy AgreementsStore
        AgreementsStore agreementsStore = new AgreementsStore();
        agreementsStore.initialize(nvmConfigAddress);
        
        // Deploy PaymentsVault
        PaymentsVault paymentsVault = new PaymentsVault();
        paymentsVault.initialize(nvmConfigAddress);
        
        // Note: For registering contracts in NVMConfig, you would need to run a separate command
        // with the governor's mnemonic index, as that requires governor privileges
        
        vm.stopBroadcast();
        
        return (assetsRegistry, agreementsStore, paymentsVault);
    }
}
