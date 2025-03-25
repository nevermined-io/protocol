// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TokenUtils} from "../../contracts/utils/TokenUtils.sol";
import {DeployConfig} from "./DeployConfig.sol";

contract DeployLibraries is Script, DeployConfig {
    function run() public returns (address) {
        uint256 deployerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy TokenUtils library
        address tokenUtilsAddress = address(new TokenUtils());
        
        vm.stopBroadcast();
        
        console.log("TokenUtils deployed at:", tokenUtilsAddress);
        
        return tokenUtilsAddress;
    }
}
