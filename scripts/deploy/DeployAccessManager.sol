// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {DeployConfig} from './DeployConfig.sol';
import {AccessManager} from '@openzeppelin/contracts/access/manager/AccessManager.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

contract DeployAccessManager is Script, DeployConfig {
    function run(address ownerAddress) public returns (AccessManager) {
        console.log('Deploying AccessManager with Owner:', ownerAddress);

        vm.startBroadcast(ownerAddress);
        AccessManager accessManager = new AccessManager(ownerAddress);
        vm.stopBroadcast();

        console.log('AccessManager deployed at:', address(accessManager));

        return accessManager;
    }
}
