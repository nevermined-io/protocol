// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../../scripts/Constants.sol";
import {DeployConfig} from "./DeployConfig.sol";
import {NVMConfig} from "../../contracts/NVMConfig.sol";
import {PaymentsVault} from "../../contracts/PaymentsVault.sol";
import {NFT1155Credits} from "../../contracts/token/NFT1155Credits.sol";


contract OwnerGrantRoles is Script, DeployConfig {
    function run(
        address nvmConfigAddress, 
        address ownerAddress, 
        address paymentsVaultAddress, 
        address nftCreditsAddress,
        address lockPaymentConditionAddress, 
        address transferCreditsConditionAddress,
        address distributePaymentsConditionAddress
    ) public {
        // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
        vm.startBroadcast(ownerAddress);                

        NVMConfig nvmConfig = NVMConfig(nvmConfigAddress);
        address payable paymentsVaultPayable = payable(paymentsVaultAddress);
        PaymentsVault paymentsVault = PaymentsVault(paymentsVaultPayable);
        NFT1155Credits nftCredits = NFT1155Credits(nftCreditsAddress);

        bytes32 DEPOSITOR_ROLE = paymentsVault.DEPOSITOR_ROLE();
        bytes32 WITHDRAW_ROLE = paymentsVault.WITHDRAW_ROLE();

        nvmConfig.grantRole(DEPOSITOR_ROLE, lockPaymentConditionAddress);
        nvmConfig.grantRole(WITHDRAW_ROLE, distributePaymentsConditionAddress);           
        
        // Grant roles for NFT1155Credits
        bytes32 CREDITS_MINTER_ROLE = nftCredits.CREDITS_MINTER_ROLE();
         nvmConfig.grantRole(CREDITS_MINTER_ROLE, transferCreditsConditionAddress);

        vm.stopBroadcast();
                
    }
}
