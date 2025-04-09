// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import { Script } from 'forge-std/Script.sol';
import { Constants } from '../../scripts/Constants.sol';
import { DeployConfig } from './DeployConfig.sol';
import { INVMConfig } from '../../contracts/interfaces/INVMConfig.sol';
import { NVMConfig } from '../../contracts/NVMConfig.sol';
import { PaymentsVault } from '../../contracts/PaymentsVault.sol';
import { NFT1155Credits } from '../../contracts/token/NFT1155Credits.sol';

contract ManagePermissions is Script, DeployConfig {
  function run(
    address governorAddress,
    address nvmConfigAddress,
    address paymentsVaultAddress,
    address nftCreditsAddress,
    address lockPaymentConditionAddress,
    address distributePaymentsConditionAddress,
    address transferCreditsConditionAddress,
    address fixedPaymentTemplateAddress
  ) public {
    // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
    vm.startBroadcast(governorAddress);

    // Get the current sender address to use as owner
    // owner = msg.sender;

    // Get contract instances
    address payable paymentsVaultPayable = payable(paymentsVaultAddress);
    PaymentsVault paymentsVault = PaymentsVault(paymentsVaultPayable);
    NFT1155Credits nftCredits = NFT1155Credits(nftCreditsAddress);
    // NFT1155ExpirableCredits nftCredits = NFT1155ExpirableCredits(nftExpirableCreditsAddress);
    // Get NVMConfig instance if needed
    NVMConfig nvmConfig = NVMConfig(nvmConfigAddress);

    // Grant roles for PaymentsVault
    // bytes32 DEPOSITOR_ROLE = paymentsVault.DEPOSITOR_ROLE();
    // bytes32 WITHDRAW_ROLE = paymentsVault.WITHDRAW_ROLE();

    bool isGovernor = nvmConfig.isGovernor(governorAddress);
    // console.log(true);

    // nvmConfig.grantRole(DEPOSITOR_ROLE, lockPaymentConditionAddress);
    // nvmConfig.grantRole(WITHDRAW_ROLE, distributePaymentsConditionAddress);

    // Grant roles for NFT1155Credits
    // bytes32 CREDITS_MINTER_ROLE = nftCredits.CREDITS_MINTER_ROLE();
    // nvmConfig.grantRole(CREDITS_MINTER_ROLE, transferCreditsConditionAddress);

    nvmConfig.grantCondition(lockPaymentConditionAddress);
    nvmConfig.grantCondition(distributePaymentsConditionAddress);
    nvmConfig.grantCondition(transferCreditsConditionAddress);

    nvmConfig.grantTemplate(fixedPaymentTemplateAddress);

    vm.stopBroadcast();
  }
}
