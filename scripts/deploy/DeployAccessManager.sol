// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import {DeployConfig} from './DeployConfig.sol';

import {Create2DeployUtils} from './common/Create2DeployUtils.sol';
import {AccessManager} from '@openzeppelin/contracts/access/manager/AccessManager.sol';
import {Script} from 'lib/forge-std/src/Script.sol';
import {console2} from 'lib/forge-std/src/console2.sol';

contract DeployAccessManager is DeployConfig, Create2DeployUtils {
    error InvalidAccessManagerDeployment_OnwerIsNotAdmin(address owner);

    function run(address ownerAddress, bytes32 deploymentSalt, bool revertIfAlreadyDeployed)
        public
        returns (AccessManager accessManager)
    {
        vm.startBroadcast(ownerAddress);
        (address accessManagerAddress,) = deployWithSanityChecks(
            deploymentSalt,
            abi.encodePacked(type(AccessManager).creationCode, abi.encode(ownerAddress)),
            revertIfAlreadyDeployed
        );
        accessManager = AccessManager(accessManagerAddress);
        vm.stopBroadcast();

        if (debug) console2.log('AccessManager deployed at:', accessManagerAddress);

        // Perform santity checks
        (bool hasRole,) = accessManager.hasRole(accessManager.ADMIN_ROLE(), ownerAddress);
        require(hasRole, InvalidAccessManagerDeployment_OnwerIsNotAdmin(ownerAddress));

        return accessManager;
    }
}
