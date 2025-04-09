// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { Script } from 'forge-std/Script.sol';
import { Constants } from '../../scripts/Constants.sol';
import { DeployConfig } from './DeployConfig.sol';
import { INVMConfig } from '../../contracts/interfaces/INVMConfig.sol';
import { NFT1155Credits } from '../../contracts/token/NFT1155Credits.sol';
import { NFT1155ExpirableCredits } from '../../contracts/token/NFT1155ExpirableCredits.sol';

contract DeployNFTContracts is Script, DeployConfig {
  function run(
    address nvmConfigAddress,
    address assetsRegistryAddress,
    address ownerAddress
  ) public returns (NFT1155Credits, NFT1155ExpirableCredits) {
    // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
    vm.startBroadcast(ownerAddress);

    // Deploy NFT1155Credits
    NFT1155Credits nftCredits = new NFT1155Credits();
    nftCredits.initialize(nvmConfigAddress, assetsRegistryAddress, 'Nevermined Credits', 'NMCR');

    // Deploy NFT1155Credits
    NFT1155ExpirableCredits nftExpirableCredits = new NFT1155ExpirableCredits();
    nftExpirableCredits.initialize(
      nvmConfigAddress,
      assetsRegistryAddress,
      'Nevermined Expirable Credits',
      'NMEX'
    );

    vm.stopBroadcast();

    return (nftCredits, nftExpirableCredits);
  }
}
