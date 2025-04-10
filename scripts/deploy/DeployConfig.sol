// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from 'forge-std/Script.sol';

contract DeployConfig is Script {
    address public owner;
    address public governor;
    uint256 public networkFee;
    address public feeReceiver;

    constructor() {
        // Default values for network fee
        networkFee = 10000; // 1% by default

        // For owner and governor addresses, we'll get them from the broadcast signer
        // when script is run with --mnemonics and --mnemonic-indexes

        // Set owner and governor to default values that will be updated in the deploy script
        owner = address(0);
        governor = address(0);

        if (vm.envExists('NVM_FEE_AMOUNT')) {
            networkFee = vm.envUint('NVM_FEE_AMOUNT');
        }

        if (vm.envExists('NVM_FEE_RECEIVER')) {
            feeReceiver = vm.envAddress('NVM_FEE_RECEIVER');
        } else {
            feeReceiver = address(this); // Will be updated to the correct address in the deploy script
        }
    }
}
