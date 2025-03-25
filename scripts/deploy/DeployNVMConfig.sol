// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {NVMConfig} from "../../contracts/NVMConfig.sol";
import {DeployConfig} from "./DeployConfig.sol";

contract DeployNVMConfig is Script, DeployConfig {
    function run() public returns (NVMConfig) {
        // Derive owner key from mnemonic
        string memory mnemonic = vm.envString("MNEMONIC");
        uint256 ownerIndex = vm.envUint("OWNER_INDEX");
        uint256 ownerKey = uint256(vm.createKey(mnemonic, ownerIndex));
        vm.startBroadcast(ownerKey);
        
        // Deploy NVMConfig
        NVMConfig nvmConfig = new NVMConfig();
        
        // Initialize NVMConfig
        nvmConfig.initialize(owner, governor);
        
        // Set network fees (called by governor)
        vm.stopBroadcast();
        
        // Derive governor key from mnemonic
        uint256 governorIndex = vm.envUint("GOVERNOR_INDEX");
        uint256 governorKey = uint256(vm.createKey(mnemonic, governorIndex));
        vm.startBroadcast(governorKey);
        nvmConfig.setNetworkFees(networkFee, feeReceiver);
        vm.stopBroadcast();
        
        return nvmConfig;
    }
}
