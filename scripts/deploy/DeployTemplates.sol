// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../Constants.sol";
import {DeployConfig} from "./DeployConfig.sol";
import {INVMConfig} from "../../contracts/interfaces/INVMConfig.sol";
import {FixedPaymentTemplate} from "../../contracts/agreements/FixedPaymentTemplate.sol";

contract DeployTemplates is Script, DeployConfig {
    function run(
        address nvmConfigAddress,
        address agreementsStoreAddress,
        address lockPaymentConditionAddress,
        address transferCreditsConditionAddress,
        address distributePaymentsConditionAddress
    ) public returns (FixedPaymentTemplate) {
        // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
        vm.startBroadcast();
        
        // Get the current sender address to use as owner
        owner = msg.sender;
        
        // For governor operations, you would need to run a separate command with the governor index
        // This script assumes the owner is deploying the contracts
        INVMConfig nvmConfig = INVMConfig(nvmConfigAddress);
        
        // Deploy FixedPaymentTemplate
        FixedPaymentTemplate fixedPaymentTemplate = new FixedPaymentTemplate();
        fixedPaymentTemplate.initialize(
            nvmConfigAddress,
            agreementsStoreAddress,
            lockPaymentConditionAddress,
            transferCreditsConditionAddress,
            distributePaymentsConditionAddress
        );
        
        // Note: For registering contracts in NVMConfig, you would need to run a separate command
        // with the governor's mnemonic index, as that requires governor privileges
        
        vm.stopBroadcast();
        
        return fixedPaymentTemplate;
    }
}
