// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {IAsset} from '../../contracts/interfaces/IAsset.sol';
import {INVMConfig} from '../../contracts/interfaces/INVMConfig.sol';
import {NFT1155Credits} from '../../contracts/token/NFT1155Credits.sol';
import {NFT1155ExpirableCredits} from '../../contracts/token/NFT1155ExpirableCredits.sol';
import {DeployConfig} from './DeployConfig.sol';
import {Create2DeployUtils} from './common/Create2DeployUtils.sol';
import {UpgradeableContractDeploySalt} from './common/Types.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';
import {Script} from 'lib/forge-std/src/Script.sol';
import {console2} from 'lib/forge-std/src/console2.sol';

contract DeployNFTContracts is DeployConfig, Create2DeployUtils {
    error NFT1155CreditsDeployment_InvalidAuthority(address authority);
    error NFT1155ExpirableCreditsDeployment_InvalidAuthority(address authority);
    error InvalidSalt();

    function run(
        IAccessManager accessManagerAddress,
        address ownerAddress,
        IAsset assetsRegistryAddress,
        UpgradeableContractDeploySalt memory nftCreditsSalt,
        UpgradeableContractDeploySalt memory nftExpirableCreditsSalt,
        bool revertIfAlreadyDeployed
    ) public returns (NFT1155Credits, NFT1155ExpirableCredits) {
        // Check for zero salts
        require(
            nftCreditsSalt.implementationSalt != bytes32(0) && nftExpirableCreditsSalt.implementationSalt != bytes32(0),
            InvalidSalt()
        );

        if (debug) {
            console2.log('Deploying NFT Contracts with:');
            console2.log('\tAssetsRegistry:', address(assetsRegistryAddress));
            console2.log('\tAccessManager:', address(accessManagerAddress));
            console2.log('\tOwner:', ownerAddress);
        }

        vm.startBroadcast(ownerAddress);

        // Deploy NFT1155Credits
        NFT1155Credits nftCredits =
            deployNFT1155Credits(accessManagerAddress, assetsRegistryAddress, nftCreditsSalt, revertIfAlreadyDeployed);

        // Deploy NFT1155ExpirableCredits
        NFT1155ExpirableCredits nftExpirableCredits = deployNFT1155ExpirableCredits(
            accessManagerAddress, assetsRegistryAddress, nftExpirableCreditsSalt, revertIfAlreadyDeployed
        );

        vm.stopBroadcast();

        return (nftCredits, nftExpirableCredits);
    }

    function deployNFT1155Credits(
        IAccessManager accessManagerAddress,
        IAsset assetsRegistryAddress,
        UpgradeableContractDeploySalt memory nftCreditsSalt,
        bool revertIfAlreadyDeployed
    ) public returns (NFT1155Credits nftCredits) {
        // Check for zero salt
        require(nftCreditsSalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy NFT1155Credits Implementation
        if (debug) console2.log('Deploying NFT1155Credits Implementation');
        (address nftCreditsImpl,) = deployWithSanityChecks(
            nftCreditsSalt.implementationSalt, type(NFT1155Credits).creationCode, revertIfAlreadyDeployed
        );
        if (debug) console2.log('NFT1155Credits Implementation deployed at:', address(nftCreditsImpl));

        // Deploy NFT1155Credits Proxy
        if (debug) console2.log('Deploying NFT1155Credits Proxy');
        bytes memory nftCreditsInitData = abi.encodeCall(
            NFT1155Credits.initialize, (accessManagerAddress, assetsRegistryAddress, 'Nevermined Credits', 'NVMC')
        );
        (address nftCreditsProxy,) = deployWithSanityChecks(
            nftCreditsSalt.proxySalt,
            getERC1967ProxyCreationCode(address(nftCreditsImpl), nftCreditsInitData),
            revertIfAlreadyDeployed
        );
        nftCredits = NFT1155Credits(nftCreditsProxy);
        if (debug) console2.log('NFT1155Credits Proxy deployed at:', address(nftCredits));

        // Verify deployment
        require(
            nftCredits.authority() == address(accessManagerAddress),
            NFT1155CreditsDeployment_InvalidAuthority(address(nftCredits.authority()))
        );
    }

    function deployNFT1155ExpirableCredits(
        IAccessManager accessManagerAddress,
        IAsset assetsRegistryAddress,
        UpgradeableContractDeploySalt memory nftExpirableCreditsSalt,
        bool revertIfAlreadyDeployed
    ) public returns (NFT1155ExpirableCredits nftExpirableCredits) {
        // Check for zero salt
        require(nftExpirableCreditsSalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy NFT1155ExpirableCredits Implementation
        if (debug) console2.log('Deploying NFT1155ExpirableCredits Implementation');
        (address nftExpirableCreditsImpl,) = deployWithSanityChecks(
            nftExpirableCreditsSalt.implementationSalt,
            type(NFT1155ExpirableCredits).creationCode,
            revertIfAlreadyDeployed
        );
        if (debug) {
            console2.log('NFT1155ExpirableCredits Implementation deployed at:', address(nftExpirableCreditsImpl));
        }

        // Deploy NFT1155ExpirableCredits Proxy
        if (debug) console2.log('Deploying NFT1155ExpirableCredits Proxy');
        bytes memory nftExpirableCreditsInitData = abi.encodeCall(
            NFT1155ExpirableCredits.initialize,
            (accessManagerAddress, assetsRegistryAddress, 'Nevermined Expirable Credits', 'NVMEC')
        );
        (address nftExpirableCreditsProxy,) = deployWithSanityChecks(
            nftExpirableCreditsSalt.proxySalt,
            getERC1967ProxyCreationCode(address(nftExpirableCreditsImpl), nftExpirableCreditsInitData),
            revertIfAlreadyDeployed
        );
        nftExpirableCredits = NFT1155ExpirableCredits(nftExpirableCreditsProxy);
        if (debug) console2.log('NFT1155ExpirableCredits Proxy deployed at:', address(nftExpirableCredits));

        // Verify deployment
        require(
            nftExpirableCredits.authority() == address(accessManagerAddress),
            NFT1155ExpirableCreditsDeployment_InvalidAuthority(address(nftExpirableCredits.authority()))
        );
    }
}
