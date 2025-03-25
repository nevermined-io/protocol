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
        // Derive keys from mnemonic
        string memory mnemonic = vm.envString("MNEMONIC");
        uint256 ownerIndex = vm.envUint("OWNER_INDEX");
        uint256 governorIndex = vm.envUint("GOVERNOR_INDEX");
        uint256 ownerKey = vm.deriveKey(mnemonic, ownerIndex);
        uint256 governorKey = vm.deriveKey(mnemonic, governorIndex);
        INVMConfig nvmConfig = INVMConfig(nvmConfigAddress);
        
        // Deploy AssetsRegistry
        vm.startBroadcast(ownerKey);
        AssetsRegistry assetsRegistry = new AssetsRegistry();
        assetsRegistry.initialize(nvmConfigAddress);
        vm.stopBroadcast();
        
        // Register AssetsRegistry in NVMConfig (called by governor)
        // Using direct call to NVMConfig since registerContract is not in the interface
        vm.startBroadcast(governorKey);
        (bool success, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "registerContract(bytes32,address,uint256)",
                Constants.HASH_ASSETS_REGISTRY,
                address(assetsRegistry),
                1
            )
        );
        require(success, "Failed to register AssetsRegistry");
        vm.stopBroadcast();
        
        // Deploy AgreementsStore
        vm.startBroadcast(ownerKey);
        AgreementsStore agreementsStore = new AgreementsStore();
        agreementsStore.initialize(nvmConfigAddress);
        vm.stopBroadcast();
        
        // Register AgreementsStore in NVMConfig (called by governor)
        // Using direct call to NVMConfig since registerContract is not in the interface
        vm.startBroadcast(governorKey);
        (bool success2, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "registerContract(bytes32,address,uint256)",
                Constants.HASH_AGREEMENTS_STORE,
                address(agreementsStore),
                1
            )
        );
        require(success2, "Failed to register AgreementsStore");
        vm.stopBroadcast();
        
        // Deploy PaymentsVault
        vm.startBroadcast(ownerKey);
        PaymentsVault paymentsVault = new PaymentsVault();
        paymentsVault.initialize(nvmConfigAddress);
        vm.stopBroadcast();
        
        // Register PaymentsVault in NVMConfig (called by governor)
        // Using direct call to NVMConfig since registerContract is not in the interface
        vm.startBroadcast(governorKey);
        (bool success3, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "registerContract(bytes32,address,uint256)",
                Constants.HASH_PAYMENTS_VAULT,
                address(paymentsVault),
                1
            )
        );
        require(success3, "Failed to register PaymentsVault");
        vm.stopBroadcast();
        
        return (assetsRegistry, agreementsStore, paymentsVault);
    }
}
