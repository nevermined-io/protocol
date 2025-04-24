// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {DeployConfig} from './DeployConfig.sol';
import {ManagePermissions} from './ManagePermissions.sol';

import {SetNetworkFees} from './SetNetworkFees.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract ConfigureAll is Script, DeployConfig {
    bool public debug = vm.envOr('DEBUG', false);

    function run() public {

        address governorAddress = msg.sender;

        if (debug) console2.log('Configuring contracts with Governor address:', governorAddress);

        string memory addressesJson = vm.envOr('DEPLOYMENT_ADDRESSES_JSON', string('./deployments/latest.json'));

        string memory json = vm.readFile(addressesJson);

        console2.log('Configuring contracts with JSON addresses from file:', addressesJson);
        if (debug) console2.log(json);

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
        if (debug) console2.log('Permissions configured');

        setNetworkFees.run(governorAddress, vm.parseJsonAddress(json, '$.contracts.NVMConfig'));


        string memory blockNumberJson = vm.toString(block.number);
        vm.writeJson(blockNumberJson, addressesJson, "$.blockNumber");
        if (debug) console2.log('Added block number to JSON:', block.number);

        uint256 snapshotId = vm.snapshotState();
        string memory snapshotIdString = vm.toString(snapshotId);
        vm.writeJson(snapshotIdString, addressesJson, "$.snapshotId");
        if (debug) console2.log('Added snapshot id to JSON:', snapshotId);

    }
}
