// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {NVMConfig} from "../../contracts/NVMConfig.sol";
import {DeployConfig} from "./DeployConfig.sol";

contract DeployNVMConfig is Script, DeployConfig {
    function run() public returns (NVMConfig) {
        // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
        vm.startBroadcast();
        
        // Get the current sender address to use as owner
        address deployerAddress = msg.sender;
        owner = deployerAddress;
        
        // For governor, we'll use a separate address in production
        // For testing, you can use the same address by setting GOVERNOR_ADDRESS env var
        governor = vm.envOr("GOVERNOR_ADDRESS", deployerAddress);
        
        // Update fee receiver if not set
        if (feeReceiver == address(this)) {
            feeReceiver = owner;
        }
        
        // Deploy NVMConfig
        NVMConfig nvmConfig = new NVMConfig();
        
        // Initialize NVMConfig with owner and governor addresses
        nvmConfig.initialize(owner, governor);
        
        // Note: Setting network fees requires the governor role
        // This should be done in a separate step after deployment
        // using the governor's private key
        
        vm.stopBroadcast();
        
        return nvmConfig;
    }
}
