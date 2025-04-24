// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {TokenUtils} from '../../contracts/utils/TokenUtils.sol';
import {DeployConfig} from './DeployConfig.sol';
import {Create2DeployUtils} from './common/Create2DeployUtils.sol';
import {UpgradeableContractDeploySalt} from './common/Types.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract DeployLibraries is DeployConfig, Create2DeployUtils {
    error TokenUtilsDeployment_Failed();
    error InvalidSalt();
    
    function run(
        address ownerAddress,
        UpgradeableContractDeploySalt memory tokenUtilsSalt,
        bool revertIfAlreadyDeployed
    ) public returns (address) {
        if (debug) {
            console2.log('Deploying Libraries with:');
            console2.log('\tOwner:', ownerAddress);
        }
        
        // Check for zero salt
        require(tokenUtilsSalt.implementationSalt != bytes32(0), InvalidSalt());

        vm.startBroadcast(ownerAddress);

        // Deploy TokenUtils library
        address tokenUtilsAddress = deployTokenUtils(tokenUtilsSalt, revertIfAlreadyDeployed);

        vm.stopBroadcast();

        return tokenUtilsAddress;
    }

    function deployTokenUtils(UpgradeableContractDeploySalt memory tokenUtilsSalt, bool revertIfAlreadyDeployed)
        public
        returns (address tokenUtilsAddress)
    {
        // Check for zero salt
        require(tokenUtilsSalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy TokenUtils library
        if (debug) console2.log('Deploying TokenUtils Library');
        (tokenUtilsAddress,) = deployWithSanityChecks(
            tokenUtilsSalt.implementationSalt, type(TokenUtils).creationCode, revertIfAlreadyDeployed
        );
        if (debug) console2.log('TokenUtils Library deployed at:', tokenUtilsAddress);

        // Verify deployment
        require(tokenUtilsAddress.code.length != 0, TokenUtilsDeployment_Failed());
    }
}
