// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {DeployConfig} from './DeployConfig.sol';
import {AccessManager} from '@openzeppelin/contracts/access/manager/AccessManager.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract DeployAccessManager is Script, DeployConfig {
    function run(address ownerAddress) public returns (AccessManager) {
        console2.log('Deploying AccessManager with Owner:', ownerAddress);

        vm.startBroadcast(ownerAddress);
        AccessManager accessManager = new AccessManager(ownerAddress);
        vm.stopBroadcast();

        console2.log('AccessManager deployed at:', address(accessManager));

        return accessManager;
    }
}
