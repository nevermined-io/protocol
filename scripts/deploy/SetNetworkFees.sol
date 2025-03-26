// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {NVMConfig} from "../../contracts/NVMConfig.sol";
import {DeployConfig} from "./DeployConfig.sol";

/**
 * @notice This script sets the network fees in the NVMConfig contract
 * @dev Must be executed with the governor's mnemonic index
 */
contract SetNetworkFees is Script, DeployConfig {
    function run(
        address governorAddress,
        address nvmConfigAddress
    ) public {
        // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
        // This must be the governor account
        vm.startBroadcast(governorAddress);

        address feeReceiver = vm.envOr('NVM_FEE_RECEIVER', governorAddress);               
        uint256 feeAmount = vm.envOr('NVM_FEE_AMOUNT', uint256(10000));
        
        // Get NVMConfig instance
        NVMConfig nvmConfig = NVMConfig(nvmConfigAddress);
        
        // Set network fees (requires governor role)
        nvmConfig.setNetworkFees(feeAmount, feeReceiver);
        
        console.log("Network fees set to:", feeAmount, "to address:", feeReceiver);

        vm.stopBroadcast();
    }
}
