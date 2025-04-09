// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { Script } from 'forge-std/Script.sol';
import { console } from 'forge-std/console.sol';
import { DeployConfig } from './DeployConfig.sol';
import { NVMConfig } from '../../contracts/NVMConfig.sol';
import { PaymentsVault } from '../../contracts/PaymentsVault.sol';
import { NFT1155Credits } from '../../contracts/token/NFT1155Credits.sol';
import { AccessManager } from '@openzeppelin/contracts/access/manager/AccessManager.sol';

contract OwnerGrantRoles is Script, DeployConfig {
  function run(
    address nvmConfigAddress,
    address ownerAddress,
    address paymentsVaultAddress,
    address nftCreditsAddress,
    address lockPaymentConditionAddress,
    address transferCreditsConditionAddress,
    address distributePaymentsConditionAddress,
    address accessManagerAddress
  ) public {
    console.log('Granting roles with:');
    console.log('\tNVMConfig:', nvmConfigAddress);
    console.log('\tOwner:', ownerAddress);
    console.log('\tPaymentsVault:', paymentsVaultAddress);
    console.log('\tNFT1155Credits:', nftCreditsAddress);
    console.log('\tLockPaymentCondition:', lockPaymentConditionAddress);
    console.log('\tTransferCreditsCondition:', transferCreditsConditionAddress);
    console.log('\tDistributePaymentsCondition:', distributePaymentsConditionAddress);
    console.log('\tAccessManager:', accessManagerAddress);

    vm.startBroadcast(ownerAddress);

    NVMConfig nvmConfig = NVMConfig(nvmConfigAddress);
    address payable paymentsVaultPayable = payable(paymentsVaultAddress);
    PaymentsVault paymentsVault = PaymentsVault(paymentsVaultPayable);
    NFT1155Credits nftCredits = NFT1155Credits(nftCreditsAddress);
    AccessManager accessManager = AccessManager(accessManagerAddress);

    // Grant roles for PaymentsVault
    bytes32 DEPOSITOR_ROLE = paymentsVault.DEPOSITOR_ROLE();
    bytes32 WITHDRAW_ROLE = paymentsVault.WITHDRAW_ROLE();

    nvmConfig.grantRole(DEPOSITOR_ROLE, lockPaymentConditionAddress);
    nvmConfig.grantRole(WITHDRAW_ROLE, distributePaymentsConditionAddress);

    // Grant roles for NFT1155Credits
    bytes32 CREDITS_MINTER_ROLE = nftCredits.CREDITS_MINTER_ROLE();
    nvmConfig.grantRole(CREDITS_MINTER_ROLE, transferCreditsConditionAddress);

    // Grant roles for AccessManager
    uint64 UPGRADE_ROLE = uint64(uint256(keccak256(abi.encode('UPGRADE_ROLE'))));
    accessManager.grantRole(UPGRADE_ROLE, ownerAddress, 0);

    vm.stopBroadcast();
  }
}
