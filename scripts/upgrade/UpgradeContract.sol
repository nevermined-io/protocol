// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { Script } from 'forge-std/Script.sol';
import { console } from 'forge-std/console.sol';
import { INVMConfig } from '../../contracts/interfaces/INVMConfig.sol';

contract UpgradeContract is Script {
  function run(address nvmConfigAddress, bytes32 contractName, address newImplementation) public {
    require(newImplementation != address(0), 'New implementation address cannot be zero');

    INVMConfig nvmConfig = INVMConfig(nvmConfigAddress);

    // Get the current version of the contract using direct call
    (bool success, bytes memory data) = nvmConfigAddress.call(
      abi.encodeWithSignature('getContractVersion(bytes32)', contractName)
    );
    require(success, 'Failed to get contract version');
    uint256 currentVersion = abi.decode(data, (uint256));

    // Register the new implementation with an incremented version using direct call
    // Uses the signer provided by --mnemonics and --mnemonic-indexes
    vm.startBroadcast();
    (bool success2, ) = nvmConfigAddress.call(
      abi.encodeWithSignature(
        'registerContract(bytes32,address,uint256)',
        contractName,
        newImplementation,
        currentVersion + 1
      )
    );
    require(success2, 'Failed to register new contract implementation');
    vm.stopBroadcast();

    console.log('Contract upgraded successfully');
    console.log('Contract name:', vm.toString(contractName));
    console.log('New implementation:', newImplementation);
    console.log('New version:', currentVersion + 1);
  }
}
