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
        
        // Set governor address - in a real deployment, this would be a different address
        // When running with --mnemonic-indexes, you would use a different index for governor
        governor = vm.envOr("GOVERNOR_ADDRESS", deployerAddress);
        
        // Update fee receiver if not set
        if (feeReceiver == address(this)) {
            feeReceiver = owner;
        }
        
        // Deploy NVMConfig
        NVMConfig nvmConfig = new NVMConfig();
        
        // Initialize NVMConfig
        nvmConfig.initialize(owner, governor);
        
        // Set network fees
        nvmConfig.setNetworkFees(networkFee, feeReceiver);
        
        vm.stopBroadcast();
        
        return nvmConfig;
    }
}
