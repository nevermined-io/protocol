// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {NVMConfig} from "../../contracts/NVMConfig.sol";
import {AssetsRegistry} from "../../contracts/AssetsRegistry.sol";
import {PaymentsVault} from "../../contracts/PaymentsVault.sol";
import {NFT1155Credits} from "../../contracts/token/NFT1155Credits.sol";
import {NFT1155ExpirableCredits} from "../../contracts/token/NFT1155ExpirableCredits.sol";
import {AgreementsStore} from "../../contracts/agreements/AgreementsStore.sol";
import {FixedPaymentTemplate} from "../../contracts/agreements/FixedPaymentTemplate.sol";
import {LockPaymentCondition} from "../../contracts/conditions/LockPaymentCondition.sol";
import {TransferCreditsCondition} from "../../contracts/conditions/TransferCreditsCondition.sol";
import {DistributePaymentsCondition} from "../../contracts/conditions/DistributePaymentsCondition.sol";

/**
 * @title TransferOwnership
 * @notice Foundry script to transfer ownership of all OwnableUpgradeable contracts
 * @dev Run with: forge script script/foundry/TransferOwnership.s.sol --rpc-url <RPC_URL> --broadcast
 */
contract TransferOwnership is Script {
    // Contract addresses - these should be set before running the script
    address public nvmConfigAddress;
    address public assetsRegistryAddress;
    address public paymentsVaultAddress;
    address public nft1155CreditsAddress;
    address public nft1155ExpirableCreditsAddress;
    address public agreementsStoreAddress;
    address public fixedPaymentTemplateAddress;
    address public lockPaymentConditionAddress;
    address public transferCreditsConditionAddress;
    address public distributePaymentsConditionAddress;

    // New owner address
    address public newOwner;

    function setUp() public {
        // Load addresses from environment variables
        nvmConfigAddress = vm.envAddress("NVM_CONFIG_ADDRESS");
        assetsRegistryAddress = vm.envAddress("ASSETS_REGISTRY_ADDRESS");
        paymentsVaultAddress = vm.envAddress("PAYMENTS_VAULT_ADDRESS");
        nft1155CreditsAddress = vm.envAddress("NFT1155_CREDITS_ADDRESS");
        nft1155ExpirableCreditsAddress = vm.envAddress("NFT1155_EXPIRABLE_CREDITS_ADDRESS");
        agreementsStoreAddress = vm.envAddress("AGREEMENTS_STORE_ADDRESS");
        fixedPaymentTemplateAddress = vm.envAddress("FIXED_PAYMENT_TEMPLATE_ADDRESS");
        lockPaymentConditionAddress = vm.envAddress("LOCK_PAYMENT_CONDITION_ADDRESS");
        transferCreditsConditionAddress = vm.envAddress("TRANSFER_CREDITS_CONDITION_ADDRESS");
        distributePaymentsConditionAddress = vm.envAddress("DISTRIBUTE_PAYMENTS_CONDITION_ADDRESS");

        // Load new owner address
        newOwner = vm.envAddress("NEW_OWNER_ADDRESS");
        
        // Ensure new owner address is set
        require(newOwner != address(0), "New owner address not set");
    }

    function run() public {
        // Start broadcasting transactions
        vm.startBroadcast();

        // Transfer ownership of each contract
        transferOwnership(nvmConfigAddress, "NVMConfig");
        transferOwnership(assetsRegistryAddress, "AssetsRegistry");
        transferOwnership(paymentsVaultAddress, "PaymentsVault");
        transferOwnership(nft1155CreditsAddress, "NFT1155Credits");
        transferOwnership(nft1155ExpirableCreditsAddress, "NFT1155ExpirableCredits");
        transferOwnership(agreementsStoreAddress, "AgreementsStore");
        transferOwnership(fixedPaymentTemplateAddress, "FixedPaymentTemplate");
        transferOwnership(lockPaymentConditionAddress, "LockPaymentCondition");
        transferOwnership(transferCreditsConditionAddress, "TransferCreditsCondition");
        transferOwnership(distributePaymentsConditionAddress, "DistributePaymentsCondition");

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }

    function transferOwnership(address contractAddress, string memory contractName) internal {
        // Skip if contract address is not set
        if (contractAddress == address(0)) {
            console.log("Skipping %s: address not set", contractName);
            return;
        }

        try OwnableUpgradeable(contractAddress).owner() returns (address currentOwner) {
            console.log("Current owner of %s: %s", contractName, currentOwner);
            
            // Transfer ownership
            OwnableUpgradeable(contractAddress).transferOwnership(newOwner);
            console.log("Ownership of %s transferred to %s", contractName, newOwner);
        } catch {
            console.log("Failed to transfer ownership of %s", contractName);
        }
    }
}
