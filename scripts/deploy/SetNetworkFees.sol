// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {NVMConfig} from "../../contracts/NVMConfig.sol";
import {DeployConfig} from "./DeployConfig.sol";

/**
 * @notice This script sets the network fees in the NVMConfig contract
 * @dev Must be executed with the governor's mnemonic index
 */
contract SetNetworkFees is Script, DeployConfig {
    function run(address nvmConfigAddress) public {
        // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
        // This must be the governor account
        vm.startBroadcast();
        
        // Get the current sender address (should be governor)
        address governorAddress = msg.sender;
        
        // Update fee receiver if not set
        if (feeReceiver == address(this)) {
            feeReceiver = governorAddress;
        }
        
        // Get NVMConfig instance
        NVMConfig nvmConfig = NVMConfig(nvmConfigAddress);
        
        // Set network fees (requires governor role)
        nvmConfig.setNetworkFees(networkFee, feeReceiver);
        
        vm.stopBroadcast();
    }
}
