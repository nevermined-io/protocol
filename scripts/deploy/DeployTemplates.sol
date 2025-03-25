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
        // Using direct call to NVMConfig since registerContract is not in the interface
        vm.startBroadcast(governorPrivateKey);
        (bool success1, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "registerContract(bytes32,address,uint256)",
                Constants.HASH_FIXED_PAYMENT_TEMPLATE,
                address(fixedPaymentTemplate),
                1
            )
        );
        require(success1, "Failed to register FixedPaymentTemplate");
        
        // Using direct call for grantTemplate since it's not in the interface
        (bool success2, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "grantTemplate(address)",
                address(fixedPaymentTemplate)
            )
        );
        require(success2, "Failed to grant template role to FixedPaymentTemplate");
        vm.stopBroadcast();
        
        return fixedPaymentTemplate;
    }
}
