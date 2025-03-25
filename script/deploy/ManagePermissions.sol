// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../Constants.sol";
import {DeployConfig} from "./DeployConfig.sol";
import {INVMConfig} from "../../contracts/interfaces/INVMConfig.sol";
import {PaymentsVault} from "../../contracts/PaymentsVault.sol";
import {NFT1155Credits} from "../../contracts/token/NFT1155Credits.sol";

contract ManagePermissions is Script, DeployConfig {
    function run(
        address nvmConfigAddress,
        address paymentsVaultAddress,
        address nftCreditsAddress,
        address lockPaymentConditionAddress,
        address distributePaymentsConditionAddress,
        address transferCreditsConditionAddress
    ) public {
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        
        // Get contract instances
        PaymentsVault paymentsVault = PaymentsVault(paymentsVaultAddress);
        NFT1155Credits nftCredits = NFT1155Credits(nftCreditsAddress);
        INVMConfig nvmConfig = INVMConfig(nvmConfigAddress);
        
        // Grant permissions
        vm.startBroadcast(ownerPrivateKey);
        
        // Grant roles for PaymentsVault
        bytes32 DEPOSITOR_ROLE = paymentsVault.DEPOSITOR_ROLE();
        bytes32 WITHDRAW_ROLE = paymentsVault.WITHDRAW_ROLE();
        
        // Using direct call for grantRole since it's not in the interface
        (bool success1, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "grantRole(bytes32,address)",
                DEPOSITOR_ROLE,
                lockPaymentConditionAddress
            )
        );
        require(success1, "Failed to grant DEPOSITOR_ROLE to LockPaymentCondition");
        
        (bool success2, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "grantRole(bytes32,address)",
                WITHDRAW_ROLE,
                distributePaymentsConditionAddress
            )
        );
        require(success2, "Failed to grant WITHDRAW_ROLE to DistributePaymentsCondition");
        
        // Grant roles for NFT1155Credits
        bytes32 CREDITS_MINTER_ROLE = nftCredits.CREDITS_MINTER_ROLE();
        
        // Using direct call for grantRole since it's not in the interface
        (bool success3, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "grantRole(bytes32,address)",
                CREDITS_MINTER_ROLE,
                transferCreditsConditionAddress
            )
        );
        require(success3, "Failed to grant CREDITS_MINTER_ROLE to TransferCreditsCondition");
        
        vm.stopBroadcast();
    }
}
