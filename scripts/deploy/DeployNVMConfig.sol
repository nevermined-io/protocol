// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {NVMConfig} from '../../contracts/NVMConfig.sol';
import {DeployConfig} from './DeployConfig.sol';
import {Create2DeployUtils} from './common/Create2DeployUtils.sol';
import {UpgradeableContractDeploySalt} from './common/Types.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract DeployNVMConfig is Script, DeployConfig, Create2DeployUtils {
    error NVMConfigDeployment_InvalidAuthority(address authority);
    error NVMConfigDeployment_InvalidGovernor(address governor);
    error InvalidSalt();

    function run(
        address ownerAddress,
        address governorAddress,
        IAccessManager accessManagerAddress,
        UpgradeableContractDeploySalt memory deploymentSalt,
        bool revertIfAlreadyDeployed
    ) public returns (NVMConfig) {
        // Check for zero salt
        require(deploymentSalt.implementationSalt != bytes32(0), InvalidSalt());

        console2.log('Deploying NVMConfig with:');
        console2.log('\tOwner:', ownerAddress);
        console2.log('\tGovernor:', governorAddress);
        console2.log('\tAccessManager:', address(accessManagerAddress));

        vm.startBroadcast(ownerAddress);

        // Update fee receiver if not set
        if (feeReceiver == address(this)) {
            feeReceiver = ownerAddress;
        }

        // Deploy NVMConfig Implementation
        console2.log('Deploying NVMConfig Implementation');
        (address nvmConfigImpl,) = deployWithSanityChecks(
            deploymentSalt.implementationSalt, type(NVMConfig).creationCode, revertIfAlreadyDeployed
        );
        console2.log('NVMConfig Implementation deployed at:', address(nvmConfigImpl));

        // Deploy NVMConfig Proxy
        console2.log('Deploying NVMConfig Proxy');
        bytes memory nvmConfigInitData =
            abi.encodeCall(NVMConfig.initialize, (ownerAddress, accessManagerAddress, governorAddress));
        (address nvmConfigProxy,) = deployWithSanityChecks(
            deploymentSalt.proxySalt,
            getERC1967ProxyCreationCode(address(nvmConfigImpl), nvmConfigInitData),
            revertIfAlreadyDeployed
        );
        NVMConfig nvmConfig = NVMConfig(nvmConfigProxy);
        console2.log('NVMConfig Proxy deployed at:', address(nvmConfig));

        // Verify deployment
        require(
            nvmConfig.authority() == address(accessManagerAddress),
            NVMConfigDeployment_InvalidAuthority(address(nvmConfig.authority()))
        );

        console2.log('NVMConfig initialized with Owner:', ownerAddress);
        console2.log('NVMConfig initialized with Governor:', governorAddress);
        console2.log('NVMConfig initialized with AccessManager:', address(accessManagerAddress));

        vm.stopBroadcast();

        return nvmConfig;
    }
}
