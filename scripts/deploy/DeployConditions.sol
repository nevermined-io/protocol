// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../../scripts/Constants.sol";
import {DeployConfig} from "./DeployConfig.sol";
import {INVMConfig} from "../../contracts/interfaces/INVMConfig.sol";
import {LockPaymentCondition} from "../../contracts/conditions/LockPaymentCondition.sol";
import {TransferCreditsCondition} from "../../contracts/conditions/TransferCreditsCondition.sol";
import {DistributePaymentsCondition} from "../../contracts/conditions/DistributePaymentsCondition.sol";
import {FiatSettlementCondition} from "../../contracts/conditions/FiatSettlementCondition.sol";

contract DeployConditions is Script, DeployConfig {
    function run(
        address ownerAddress,
        address nvmConfigAddress,
        address assetsRegistryAddress,
        address agreementsStoreAddress,
        address paymentsVaultAddress,
        address /* tokenUtilsAddress */
    ) public returns (
        LockPaymentCondition,
        TransferCreditsCondition,
        DistributePaymentsCondition,
        FiatSettlementCondition
    ) {
        // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
        vm.startBroadcast(ownerAddress);        
                
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
        
        // Deploy FiatSettlementCondition
        FiatSettlementCondition fiatSettlementCondition = new FiatSettlementCondition();
        fiatSettlementCondition.initialize(
            nvmConfigAddress,
            assetsRegistryAddress,
            agreementsStoreAddress
        );

        vm.stopBroadcast();
        
        return (
            lockPaymentCondition,
            transferCreditsCondition,
            distributePaymentsCondition,
            fiatSettlementCondition
        );
    }
}
