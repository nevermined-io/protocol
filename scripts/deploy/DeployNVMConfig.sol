// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {NVMConfig} from "../../contracts/NVMConfig.sol";
import {DeployConfig} from "./DeployConfig.sol";

contract DeployNVMConfig is Script, DeployConfig {
    function run() public returns (NVMConfig) {
        // Start broadcast as owner (using derived key from mnemonic)
        uint256 ownerKey = vm.deriveKey(mnemonic, ownerIndex);
        vm.startBroadcast(ownerKey);
        
        // Deploy NVMConfig
        NVMConfig nvmConfig = new NVMConfig();
        
        // Initialize NVMConfig
        nvmConfig.initialize(owner, governor);
        
        // Set network fees (called by governor)
        vm.stopBroadcast();
        
        // Start broadcast as governor (using derived key from mnemonic)
        uint256 governorKey = vm.deriveKey(mnemonic, governorIndex);
        vm.startBroadcast(governorKey);
        nvmConfig.setNetworkFees(networkFee, feeReceiver);
        vm.stopBroadcast();
        
        return nvmConfig;
    }
}
