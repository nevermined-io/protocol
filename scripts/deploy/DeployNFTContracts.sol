// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {NFT1155Credits} from '../../contracts/token/NFT1155Credits.sol';
import {NFT1155ExpirableCredits} from '../../contracts/token/NFT1155ExpirableCredits.sol';
import {DeployConfig} from './DeployConfig.sol';
import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract DeployNFTContracts is Script, DeployConfig {
    function run(
        address nvmConfigAddress,
        address assetsRegistryAddress,
        address accessManagerAddress,
        address ownerAddress
    ) public returns (NFT1155Credits, NFT1155ExpirableCredits) {
        console2.log('Deploying NFT Contracts with:');
        console2.log('\tNVMConfig:', nvmConfigAddress);
        console2.log('\tAssetsRegistry:', assetsRegistryAddress);
        console2.log('\tAccessManager:', accessManagerAddress);
        console2.log('\tOwner:', ownerAddress);

        vm.startBroadcast(ownerAddress);

        // Deploy NFT1155Credits
        NFT1155Credits nftCreditsImpl = new NFT1155Credits();
        bytes memory nftCreditsData = abi.encodeCall(
            NFT1155Credits.initialize,
            (nvmConfigAddress, accessManagerAddress, assetsRegistryAddress, 'Nevermined Credits', 'NVMC')
        );
        NFT1155Credits nftCredits = NFT1155Credits(address(new ERC1967Proxy(address(nftCreditsImpl), nftCreditsData)));

        // Deploy NFT1155ExpirableCredits
        NFT1155ExpirableCredits nftExpirableCreditsImpl = new NFT1155ExpirableCredits();
        bytes memory nftExpirableCreditsData = abi.encodeCall(
            NFT1155ExpirableCredits.initialize,
            (nvmConfigAddress, accessManagerAddress, assetsRegistryAddress, 'Nevermined Expirable Credits', 'NVMEC')
        );
        NFT1155ExpirableCredits nftExpirableCredits = NFT1155ExpirableCredits(
            address(new ERC1967Proxy(address(nftExpirableCreditsImpl), nftExpirableCreditsData))
        );

        vm.stopBroadcast();

        return (nftCredits, nftExpirableCredits);
    }
}
