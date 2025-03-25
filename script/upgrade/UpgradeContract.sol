// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {INVMConfig} from "../../contracts/interfaces/INVMConfig.sol";

contract UpgradeContract is Script {
    function run(
        address nvmConfigAddress,
        bytes32 contractName,
        address newImplementation
    ) public {
        require(newImplementation != address(0), "New implementation address cannot be zero");
        
        uint256 governorPrivateKey = vm.envUint("GOVERNOR_PRIVATE_KEY");
        INVMConfig nvmConfig = INVMConfig(nvmConfigAddress);
        
        // Get the current version of the contract
        uint256 currentVersion = nvmConfig.getContractVersion(contractName);
        
        // Register the new implementation with an incremented version
        vm.startBroadcast(governorPrivateKey);
        nvmConfig.registerContract(contractName, newImplementation, currentVersion + 1);
        vm.stopBroadcast();
        
        console.log("Contract upgraded successfully");
        console.log("Contract name:", vm.toString(contractName));
        console.log("New implementation:", newImplementation);
        console.log("New version:", currentVersion + 1);
    }
}
