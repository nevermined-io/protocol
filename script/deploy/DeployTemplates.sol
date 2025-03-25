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
        uint256 deployerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        uint256 governorPrivateKey = vm.envUint("GOVERNOR_PRIVATE_KEY");
        INVMConfig nvmConfig = INVMConfig(nvmConfigAddress);
        
        // Deploy FixedPaymentTemplate
        vm.startBroadcast(deployerPrivateKey);
        FixedPaymentTemplate fixedPaymentTemplate = new FixedPaymentTemplate();
        fixedPaymentTemplate.initialize(
            nvmConfigAddress,
            agreementsStoreAddress,
            lockPaymentConditionAddress,
            transferCreditsConditionAddress,
            distributePaymentsConditionAddress
        );
        vm.stopBroadcast();
        
        // Register FixedPaymentTemplate in NVMConfig (called by governor)
        vm.startBroadcast(governorPrivateKey);
        nvmConfig.registerContract(
            Constants.HASH_FIXED_PAYMENT_TEMPLATE,
            address(fixedPaymentTemplate),
            1
        );
        nvmConfig.grantTemplate(address(fixedPaymentTemplate));
        vm.stopBroadcast();
        
        return fixedPaymentTemplate;
    }
}
