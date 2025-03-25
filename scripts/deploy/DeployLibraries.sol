// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TokenUtils} from "../../contracts/utils/TokenUtils.sol";
import {DeployConfig} from "./DeployConfig.sol";

contract DeployLibraries is Script, DeployConfig {
    function run() public returns (address) {
        // Derive owner key from mnemonic
        string memory mnemonic = vm.envString("MNEMONIC");
        uint256 ownerIndex = vm.envUint("OWNER_INDEX");
        uint256 ownerKey = vm.deriveKey(mnemonic, ownerIndex);
        vm.startBroadcast(ownerKey);
        
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
