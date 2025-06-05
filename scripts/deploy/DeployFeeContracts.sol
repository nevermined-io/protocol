// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import {ProtocolStandardFees} from '../../contracts/fees/ProtocolStandardFees.sol';
import {DeployConfig} from './DeployConfig.sol';
import {Create2DeployUtils} from './common/Create2DeployUtils.sol';
import {UpgradeableContractDeploySalt} from './common/Types.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';
import {Script} from 'lib/forge-std/src/Script.sol';
import {console2} from 'lib/forge-std/src/console2.sol';

contract DeployFeeContracts is DeployConfig, Create2DeployUtils {
    error ProtocolStandardFeesDeployment_InvalidAuthority(address authority);
    error InvalidSalt();

    struct DeployFeeContractsParams {
        address ownerAddress;
        IAccessManager accessManagerAddress;
        UpgradeableContractDeploySalt protocolStandardFeesSalt;
        bool revertIfAlreadyDeployed;
    }

    function run(DeployFeeContractsParams memory params) public returns (ProtocolStandardFees) {
        require(params.protocolStandardFeesSalt.implementationSalt != bytes32(0), InvalidSalt());
        vm.startBroadcast(params.ownerAddress);

        // Deploy ProtocolStandardFees Implementation
        if (debug) console2.log('Deploying ProtocolStandardFees Implementation');
        (address protocolStandardFeesImpl,) = deployWithSanityChecks(
            params.protocolStandardFeesSalt.implementationSalt,
            type(ProtocolStandardFees).creationCode,
            params.revertIfAlreadyDeployed
        );
        if (debug) console2.log('ProtocolStandardFees Implementation deployed at:', address(protocolStandardFeesImpl));

        // Deploy ProtocolStandardFees Proxy
        if (debug) console2.log('Deploying ProtocolStandardFees Proxy');
        bytes memory protocolStandardFeesInitData =
            abi.encodeCall(ProtocolStandardFees.initialize, (params.accessManagerAddress));
        (address protocolStandardFeesProxy,) = deployWithSanityChecks(
            params.protocolStandardFeesSalt.proxySalt,
            getERC1967ProxyCreationCode(address(protocolStandardFeesImpl), protocolStandardFeesInitData),
            params.revertIfAlreadyDeployed
        );
        ProtocolStandardFees protocolStandardFees = ProtocolStandardFees(protocolStandardFeesProxy);
        if (debug) console2.log('ProtocolStandardFees Proxy deployed at:', address(protocolStandardFees));

        // Verify deployment
        require(
            protocolStandardFees.authority() == address(params.accessManagerAddress),
            ProtocolStandardFeesDeployment_InvalidAuthority(address(protocolStandardFees.authority()))
        );

        vm.stopBroadcast();
        return protocolStandardFees;
    }
}
