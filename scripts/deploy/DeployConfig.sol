// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";

contract DeployConfig is Script {
    address public owner;
    address public governor;
    uint256 public networkFee;
    address public feeReceiver;
    
    constructor() {
        // Default values that will be overridden by environment variables if available
        owner = vm.addr(1);        // Default owner from private key 1
        governor = vm.addr(2);      // Default governor from private key 2
        networkFee = 10000;        // 1% by default
        feeReceiver = owner;       // Default fee receiver is owner
        
        // Override defaults with environment variables if set
        if (vm.envExists("OWNER_PRIVATE_KEY")) {
            owner = vm.addr(vm.envUint("OWNER_PRIVATE_KEY"));
        }
        
        if (vm.envExists("GOVERNOR_PRIVATE_KEY")) {
            governor = vm.addr(vm.envUint("GOVERNOR_PRIVATE_KEY"));
        }
        
        if (vm.envExists("NVM_FEE_AMOUNT")) {
            networkFee = vm.envUint("NVM_FEE_AMOUNT");
        }
        
        if (vm.envExists("NVM_FEE_RECEIVER")) {
            feeReceiver = vm.envAddress("NVM_FEE_RECEIVER");
        } else {
            feeReceiver = owner;
        }
    }
}
