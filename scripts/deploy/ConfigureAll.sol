// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {DeployConfig} from './DeployConfig.sol';
import {ManagePermissions} from './ManagePermissions.sol';

import {SetNetworkFees} from './SetNetworkFees.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract ConfigureAll is Script, DeployConfig {
    function run() public {
        address governorAddress = msg.sender;

        console2.log('Configuring contracts with Governor address:', governorAddress);

        string memory addressesJson = vm.envOr('DEPLOYMENT_ADDRESSES_JSON', string('./deployments/latest.json'));

        string memory json = vm.readFile(addressesJson);

        console2.log('Configuring contracts with JSON addresses from file:', addressesJson);
        console2.log(json);

        // Load the deployment scripts
        ManagePermissions managePermissions = new ManagePermissions();
        SetNetworkFees setNetworkFees = new SetNetworkFees();

        managePermissions.run(
            governorAddress,
            vm.parseJsonAddress(json, '$.contracts.NVMConfig'),
            vm.parseJsonAddress(json, '$.contracts.PaymentsVault'),
            vm.parseJsonAddress(json, '$.contracts.NFT1155Credits'),
            vm.parseJsonAddress(json, '$.contracts.LockPaymentCondition'),
            vm.parseJsonAddress(json, '$.contracts.DistributePaymentsCondition'),
            vm.parseJsonAddress(json, '$.contracts.TransferCreditsCondition'),
            vm.parseJsonAddress(json, '$.contracts.FiatSettlementCondition'),
            vm.parseJsonAddress(json, '$.contracts.FixedPaymentTemplate'),
            vm.parseJsonAddress(json, '$.contracts.FiatPaymentTemplate'),
            vm.parseJsonAddress(json, '$.contracts.AccessManager')
        );
        console2.log('Permissions configured');

        setNetworkFees.run(governorAddress, vm.parseJsonAddress(json, '$.contracts.NVMConfig'));
        
        // Add block number to the existing JSON content
        string memory blockNumberJson = vm.serializeUint("", "blockNumber", block.number);
        
        // Write the block number to the existing JSON file
        // The third parameter allows adding/updating a specific key without replacing the entire JSON
        vm.writeJson(blockNumberJson, addressesJson, "blockNumber");
        
        console2.log('Added block number to JSON:', block.number);
    }
}
