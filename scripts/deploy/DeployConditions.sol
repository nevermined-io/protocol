// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../Constants.sol";
import {DeployConfig} from "./DeployConfig.sol";
import {INVMConfig} from "../../contracts/interfaces/INVMConfig.sol";
import {LockPaymentCondition} from "../../contracts/conditions/LockPaymentCondition.sol";
import {TransferCreditsCondition} from "../../contracts/conditions/TransferCreditsCondition.sol";
import {DistributePaymentsCondition} from "../../contracts/conditions/DistributePaymentsCondition.sol";

contract DeployConditions is Script, DeployConfig {
    function run(
        address nvmConfigAddress,
        address assetsRegistryAddress,
        address agreementsStoreAddress,
        address paymentsVaultAddress,
        address tokenUtilsAddress
    ) public returns (
        LockPaymentCondition,
        TransferCreditsCondition,
        DistributePaymentsCondition
    ) {
        // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
        vm.startBroadcast();
        
        // Get the current sender address to use as owner
        owner = msg.sender;
        
        // For governor operations, you would need to run a separate command with the governor index
        // This script assumes the owner is deploying the contracts
        INVMConfig nvmConfig = INVMConfig(nvmConfigAddress);
        
        // Deploy LockPaymentCondition with TokenUtils library
        LockPaymentCondition lockPaymentCondition = new LockPaymentCondition();
        lockPaymentCondition.initialize(
            nvmConfigAddress,
            assetsRegistryAddress,
            agreementsStoreAddress,
            paymentsVaultAddress
        );
        
        // Deploy TransferCreditsCondition
        TransferCreditsCondition transferCreditsCondition = new TransferCreditsCondition();
        transferCreditsCondition.initialize(
            nvmConfigAddress,
            assetsRegistryAddress,
            agreementsStoreAddress
        );
        
        // Deploy DistributePaymentsCondition with TokenUtils library
        DistributePaymentsCondition distributePaymentsCondition = new DistributePaymentsCondition();
        distributePaymentsCondition.initialize(
            nvmConfigAddress,
            assetsRegistryAddress,
            agreementsStoreAddress,
            paymentsVaultAddress
        );
        
        // Note: For registering contracts in NVMConfig, you would need to run a separate command
        // with the governor's mnemonic index, as that requires governor privileges
        
        vm.stopBroadcast();
        
        return (
            lockPaymentCondition,
            transferCreditsCondition,
            distributePaymentsCondition
        );
    }
}
