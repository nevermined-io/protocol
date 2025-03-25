// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {TokenUtils} from "../../contracts/utils/TokenUtils.sol";
import {DeployConfig} from "./DeployConfig.sol";

contract DeployLibraries is Script, DeployConfig {
    function run() public returns (TokenUtils) {
        uint256 deployerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy TokenUtils library
        TokenUtils tokenUtils = new TokenUtils();
        
        vm.stopBroadcast();
        
        return tokenUtils;
    }
}
