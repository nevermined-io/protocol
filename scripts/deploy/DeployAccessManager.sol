// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {DeployConfig} from './DeployConfig.sol';

import {Create2DeployUtils} from './common/Create2DeployUtils.sol';
import {AccessManager} from '@openzeppelin/contracts/access/manager/AccessManager.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract DeployAccessManager is Script, DeployConfig, Create2DeployUtils {
    error InvalidAccessManagerDeployment_OnwerIsNotAdmin(address owner);

    function run(address ownerAddress, bytes32 deploymentSalt, bool revertIfAlreadyDeployed)
        public
        returns (AccessManager accessManager)
    {
        console2.log('Deploying AccessManager with Owner:', ownerAddress);

        vm.startBroadcast(ownerAddress);
        (address accessManagerAddress,) = deployWithSanityChecks(
            deploymentSalt,
            abi.encodePacked(type(AccessManager).creationCode, abi.encode(ownerAddress)),
            revertIfAlreadyDeployed
        );
        accessManager = AccessManager(accessManagerAddress);
        vm.stopBroadcast();

        console2.log('AccessManager deployed at:', accessManagerAddress);

        // Perform santity checks
        (bool hasRole,) = accessManager.hasRole(accessManager.ADMIN_ROLE(), ownerAddress);
        require(hasRole, InvalidAccessManagerDeployment_OnwerIsNotAdmin(ownerAddress));

        return accessManager;
    }
}
