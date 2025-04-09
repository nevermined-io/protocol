// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../../scripts/Constants.sol";
import {DeployConfig} from "./DeployConfig.sol";
import {INVMConfig} from "../../contracts/interfaces/INVMConfig.sol";
import {FixedPaymentTemplate} from "../../contracts/agreements/FixedPaymentTemplate.sol";
import {FiatPaymentTemplate} from "../../contracts/agreements/FiatPaymentTemplate.sol";

contract DeployTemplates is Script, DeployConfig {
    function run(
        address ownerAddress,
        address nvmConfigAddress,
        address assetsRegistryAddress,
        address agreementsStoreAddress,
        address lockPaymentConditionAddress,
        address transferCreditsConditionAddress,
        address distributePaymentsConditionAddress,
        address fiatSettlementConditionAddress
    ) public returns (FixedPaymentTemplate, FiatPaymentTemplate) {
        // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
        vm.startBroadcast(ownerAddress);        
        
        // Deploy FixedPaymentTemplate
        FixedPaymentTemplate fixedPaymentTemplate = new FixedPaymentTemplate();
        fixedPaymentTemplate.initialize(
            nvmConfigAddress,
            assetsRegistryAddress,
            agreementsStoreAddress,
            lockPaymentConditionAddress,
            transferCreditsConditionAddress,
            distributePaymentsConditionAddress
        );
        
        // Deploy FiatPaymentTemplate
        FiatPaymentTemplate fiatPaymentTemplate = new FiatPaymentTemplate();
        fiatPaymentTemplate.initialize(
            nvmConfigAddress,
            assetsRegistryAddress,
            agreementsStoreAddress,
            fiatSettlementConditionAddress,
            transferCreditsConditionAddress
        );

        vm.stopBroadcast();
        
        return (fixedPaymentTemplate, fiatPaymentTemplate);
    }
}
