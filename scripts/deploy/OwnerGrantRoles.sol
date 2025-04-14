// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {NVMConfig} from '../../contracts/NVMConfig.sol';
import {PaymentsVault} from '../../contracts/PaymentsVault.sol';

import {DistributePaymentsCondition} from '../../contracts/conditions/DistributePaymentsCondition.sol';
import {LockPaymentCondition} from '../../contracts/conditions/LockPaymentCondition.sol';
import {TransferCreditsCondition} from '../../contracts/conditions/TransferCreditsCondition.sol';
import {NFT1155Credits} from '../../contracts/token/NFT1155Credits.sol';
import {DeployConfig} from './DeployConfig.sol';
import {AccessManager} from '@openzeppelin/contracts/access/manager/AccessManager.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract OwnerGrantRoles is Script, DeployConfig {
    function run(
        NVMConfig nvmConfig,
        address ownerAddress,
        PaymentsVault paymentsVault,
        NFT1155Credits nftCredits,
        LockPaymentCondition lockPaymentCondition,
        TransferCreditsCondition transferCreditsCondition,
        DistributePaymentsCondition distributePaymentsCondition,
        AccessManager accessManager
    ) public {
        console2.log('Granting roles with:');
        console2.log('\tNVMConfig:', address(nvmConfig));
        console2.log('\tOwner:', ownerAddress);
        console2.log('\tPaymentsVault:', address(paymentsVault));
        console2.log('\tNFT1155Credits:', address(nftCredits));
        console2.log('\tLockPaymentCondition:', address(lockPaymentCondition));
        console2.log('\tTransferCreditsCondition:', address(transferCreditsCondition));
        console2.log('\tDistributePaymentsCondition:', address(distributePaymentsCondition));
        console2.log('\tAccessManager:', address(accessManager));

        vm.startBroadcast(ownerAddress);

        // Grant roles for PaymentsVault
        bytes32 DEPOSITOR_ROLE = paymentsVault.DEPOSITOR_ROLE();
        bytes32 WITHDRAW_ROLE = paymentsVault.WITHDRAW_ROLE();

        nvmConfig.grantRole(DEPOSITOR_ROLE, address(lockPaymentCondition));
        nvmConfig.grantRole(WITHDRAW_ROLE, address(distributePaymentsCondition));

        // Grant roles for NFT1155Credits
        bytes32 CREDITS_MINTER_ROLE = nftCredits.CREDITS_MINTER_ROLE();
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(transferCreditsCondition));

        // Grant roles for AccessManager
        uint64 UPGRADE_ROLE = uint64(uint256(keccak256(abi.encode('UPGRADE_ROLE'))));
        accessManager.grantRole(UPGRADE_ROLE, ownerAddress, 0);

        vm.stopBroadcast();
    }
}
