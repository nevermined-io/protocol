// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {NVMConfig} from '../../contracts/NVMConfig.sol';
import {DeployConfig} from './DeployConfig.sol';

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract DeployNVMConfig is Script, DeployConfig {
    function run(address ownerAddress, address governorAddress, address accessManager) public returns (NVMConfig) {
        // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
        vm.startBroadcast(ownerAddress);

        // Update fee receiver if not set
        if (feeReceiver == address(this)) {
            feeReceiver = ownerAddress;
        }

        // Deploy NVMConfig implementation
        NVMConfig nvmConfigImpl = new NVMConfig();

        // Deploy proxy with implementation
        bytes memory initData = abi.encodeCall(NVMConfig.initialize, (ownerAddress, accessManager, governorAddress));
        ERC1967Proxy proxy = new ERC1967Proxy(address(nvmConfigImpl), initData);

        // Create NVMConfig instance pointing to proxy
        NVMConfig nvmConfig = NVMConfig(address(proxy));

        console2.log('NVMConfig implementation deployed at:', address(nvmConfigImpl));
        console2.log('NVMConfig proxy deployed at:', address(proxy));
        console2.log('NVMConfig initialized with Owner:', ownerAddress);
        console2.log('NVMConfig initialized with Governor:', governorAddress);
        console2.log('NVMConfig initialized with AccessManager:', accessManager);

        vm.stopBroadcast();

        return nvmConfig;
    }
}
