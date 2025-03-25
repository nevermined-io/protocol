// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {NVMConfig} from "../../contracts/NVMConfig.sol";
import {DeployConfig} from "./DeployConfig.sol";

contract DeployNVMConfig is Script, DeployConfig {
    function run() public returns (NVMConfig) {
        uint256 deployerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy NVMConfig
        NVMConfig nvmConfig = new NVMConfig();
        
        // Initialize NVMConfig
        nvmConfig.initialize(owner, governor);
        
        // Set network fees (called by governor)
        vm.stopBroadcast();
        
        uint256 governorPrivateKey = vm.envUint("GOVERNOR_PRIVATE_KEY");
        vm.startBroadcast(governorPrivateKey);
        nvmConfig.setNetworkFees(networkFee, feeReceiver);
        vm.stopBroadcast();
        
        return nvmConfig;
    }
}
