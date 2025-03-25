// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";

contract DeployConfig is Script {
    address public owner;
    address public governor;
    uint256 public networkFee;
    address public feeReceiver;
    string public mnemonic;
    uint256 public ownerIndex;
    uint256 public governorIndex;
    
    constructor() {
        // Default values that will be overridden by environment variables if available
        mnemonic = "test test test test test test test test test test test junk"; // Default mnemonic
        ownerIndex = 0;            // Default owner index
        governorIndex = 1;         // Default governor index
        networkFee = 10000;        // 1% by default
        
        // Override defaults with environment variables if set
        if (vm.envExists("MNEMONIC")) {
            mnemonic = vm.envString("MNEMONIC");
        }
        
        if (vm.envExists("OWNER_INDEX")) {
            ownerIndex = vm.envUint("OWNER_INDEX");
        }
        
        if (vm.envExists("GOVERNOR_INDEX")) {
            governorIndex = vm.envUint("GOVERNOR_INDEX");
        }
        
        // Derive addresses from mnemonic and indexes
        owner = vm.rememberKey(vm.deriveKey(mnemonic, ownerIndex));
        governor = vm.rememberKey(vm.deriveKey(mnemonic, governorIndex));
        
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
