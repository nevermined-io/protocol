// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import {OneTimeCreatorHook} from '../../contracts/hooks/OneTimeCreatorHook.sol';

import {DeployConfig} from './DeployConfig.sol';
import {Create2DeployUtils} from './common/Create2DeployUtils.sol';
import {UpgradeableContractDeploySalt} from './common/Types.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';
import {Script} from 'lib/forge-std/src/Script.sol';
import {console2} from 'lib/forge-std/src/console2.sol';

contract DeployHooks is DeployConfig, Create2DeployUtils {
    error OneTimeCreatorHookDeployment_InvalidAuthority(address authority);
    error InvalidSalt();

    struct DeployHooksParams {
        address ownerAddress;
        IAccessManager accessManagerAddress;
        UpgradeableContractDeploySalt oneTimeCreatorHookSalt;
        bool revertIfAlreadyDeployed;
    }

    function run(DeployHooksParams memory params) public returns (OneTimeCreatorHook) {
        require(params.oneTimeCreatorHookSalt.implementationSalt != bytes32(0), InvalidSalt());
        vm.startBroadcast(params.ownerAddress);

        // Deploy OneTimeCreatorHook Implementation
        if (debug) console2.log('Deploying OneTimeCreatorHook Implementation');
        (address oneTimeCreatorHookImpl,) = deployWithSanityChecks(
            params.oneTimeCreatorHookSalt.implementationSalt,
            type(OneTimeCreatorHook).creationCode,
            params.revertIfAlreadyDeployed
        );
        if (debug) console2.log('OneTimeCreatorHook Implementation deployed at:', address(oneTimeCreatorHookImpl));

        // Deploy OneTimeCreatorHook Proxy
        if (debug) console2.log('Deploying OneTimeCreatorHook Proxy');
        bytes memory oneTimeCreatorHookInitData =
            abi.encodeCall(OneTimeCreatorHook.initialize, (params.accessManagerAddress));
        (address oneTimeCreatorHookProxy,) = deployWithSanityChecks(
            params.oneTimeCreatorHookSalt.proxySalt,
            getERC1967ProxyCreationCode(address(oneTimeCreatorHookImpl), oneTimeCreatorHookInitData),
            params.revertIfAlreadyDeployed
        );
        OneTimeCreatorHook oneTimeCreatorHook = OneTimeCreatorHook(oneTimeCreatorHookProxy);
        if (debug) console2.log('OneTimeCreatorHook Proxy deployed at:', address(oneTimeCreatorHook));

        // Verify deployment
        require(
            oneTimeCreatorHook.authority() == address(params.accessManagerAddress),
            OneTimeCreatorHookDeployment_InvalidAuthority(address(oneTimeCreatorHook.authority()))
        );

        vm.stopBroadcast();
        return oneTimeCreatorHook;
    }
}
