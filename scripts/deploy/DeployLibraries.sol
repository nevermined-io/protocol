// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TokenUtils} from "../../contracts/utils/TokenUtils.sol";
import {DeployConfig} from "./DeployConfig.sol";

contract DeployLibraries is Script, DeployConfig {
    function run() public returns (address) {
        // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
        vm.startBroadcast();
        
        // Get the current sender address to use as owner
        owner = msg.sender;
        
        // Deploy TokenUtils library - libraries are deployed differently
        // We can't instantiate libraries with 'new', so we'll use a low-level approach
        bytes memory bytecode = type(TokenUtils).creationCode;
        bytes32 salt = keccak256(abi.encodePacked("TokenUtils", block.timestamp));
        address tokenUtilsAddress;
        
        assembly {
            tokenUtilsAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(tokenUtilsAddress)) { revert(0, 0) }
        }
        
        vm.stopBroadcast();
        
        console.log("TokenUtils deployed at:", tokenUtilsAddress);
        
        return tokenUtilsAddress;
    }
}
