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
        string memory defaultMnemonic = "test test test test test test test test test test test junk";
        uint256 defaultOwnerIndex = 0;
        uint256 defaultGovernorIndex = 1;
        networkFee = 10000;        // 1% by default
        
        // Override defaults with environment variables if set
        string memory mnemonic = defaultMnemonic;
        uint256 ownerIndex = defaultOwnerIndex;
        uint256 governorIndex = defaultGovernorIndex;
        
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
        uint256 ownerPrivateKey = uint256(vm.createKey(mnemonic, ownerIndex));
        uint256 governorPrivateKey = uint256(vm.createKey(mnemonic, governorIndex));
        owner = vm.addr(ownerPrivateKey);
        governor = vm.addr(governorPrivateKey);
        
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
