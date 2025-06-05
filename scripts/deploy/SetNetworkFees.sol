// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import {NVMConfig} from '../../contracts/NVMConfig.sol';
import {DeployConfig} from './DeployConfig.sol';
import {Script} from 'lib/forge-std/src/Script.sol';
import {console2} from 'lib/forge-std/src/console2.sol';

/**
 * @notice This script sets the network fees in the NVMConfig contract
 * @dev Must be executed with the governor's mnemonic index
 */
contract SetNetworkFees is Script, DeployConfig {
    function run() public {
        string memory addressesJson = vm.envOr('DEPLOYMENT_ADDRESSES_JSON', string('./deployments/latest.json'));
        string memory json = vm.readFile(addressesJson);
        if (debug) console2.log(json);

        address governorAddress = vm.parseJsonAddress(json, '$.governor');
        NVMConfig nvmConfig = NVMConfig(vm.parseJsonAddress(json, '$.contracts.NVMConfig'));

        address feeReceiver = vm.envOr('NVM_FEE_RECEIVER', governorAddress);

        // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
        // This must be the governor account
        vm.startBroadcast(governorAddress);
        // Set network fees (requires governor role)
        nvmConfig.setFeeReceiver(feeReceiver);

        console2.log('Fee receiver set to:', feeReceiver);

        vm.stopBroadcast();
    }
}
