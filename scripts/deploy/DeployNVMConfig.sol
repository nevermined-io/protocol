// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {NVMConfig} from "../../contracts/NVMConfig.sol";
import {DeployConfig} from "./DeployConfig.sol";
import {console} from "forge-std/console.sol";

contract DeployNVMConfig is Script, DeployConfig {
    function run(address ownerAddress, address governorAddress) public returns (NVMConfig) {
        // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
        vm.startBroadcast(ownerAddress);
                
        
        // Update fee receiver if not set
        if (feeReceiver == address(this)) {
            feeReceiver = ownerAddress;
        }
        
        // Deploy NVMConfig
        NVMConfig nvmConfig = new NVMConfig();
        
        // Initialize NVMConfig with owner and governor addresses
        nvmConfig.initialize(ownerAddress, governorAddress);
        
        console.log("NVMConfig initialized with Owner:", ownerAddress);
        console.log("NVMConfig initialized with Governor:", governorAddress);

        vm.stopBroadcast();
        
        return nvmConfig;
    }
}
