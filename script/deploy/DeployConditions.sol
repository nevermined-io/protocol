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
        uint256 deployerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        uint256 governorPrivateKey = vm.envUint("GOVERNOR_PRIVATE_KEY");
        INVMConfig nvmConfig = INVMConfig(nvmConfigAddress);
        
        // Deploy LockPaymentCondition with TokenUtils library
        vm.startBroadcast(deployerPrivateKey);
        LockPaymentCondition lockPaymentCondition = new LockPaymentCondition();
        lockPaymentCondition.initialize(
            nvmConfigAddress,
            assetsRegistryAddress,
            agreementsStoreAddress,
            paymentsVaultAddress
        );
        vm.stopBroadcast();
        
        // Register LockPaymentCondition in NVMConfig (called by governor)
        vm.startBroadcast(governorPrivateKey);
        nvmConfig.registerContract(
            Constants.HASH_LOCKPAYMENT_CONDITION,
            address(lockPaymentCondition),
            1
        );
        nvmConfig.grantCondition(address(lockPaymentCondition));
        vm.stopBroadcast();
        
        // Deploy TransferCreditsCondition
        vm.startBroadcast(deployerPrivateKey);
        TransferCreditsCondition transferCreditsCondition = new TransferCreditsCondition();
        transferCreditsCondition.initialize(
            nvmConfigAddress,
            assetsRegistryAddress,
            agreementsStoreAddress
        );
        vm.stopBroadcast();
        
        // Register TransferCreditsCondition in NVMConfig (called by governor)
        vm.startBroadcast(governorPrivateKey);
        nvmConfig.registerContract(
            Constants.HASH_TRANSFERCREDITS_CONDITION,
            address(transferCreditsCondition),
            1
        );
        nvmConfig.grantCondition(address(transferCreditsCondition));
        vm.stopBroadcast();
        
        // Deploy DistributePaymentsCondition with TokenUtils library
        vm.startBroadcast(deployerPrivateKey);
        DistributePaymentsCondition distributePaymentsCondition = new DistributePaymentsCondition();
        distributePaymentsCondition.initialize(
            nvmConfigAddress,
            assetsRegistryAddress,
            agreementsStoreAddress,
            paymentsVaultAddress
        );
        vm.stopBroadcast();
        
        // Register DistributePaymentsCondition in NVMConfig (called by governor)
        vm.startBroadcast(governorPrivateKey);
        nvmConfig.registerContract(
            Constants.HASH_DISTRIBUTEPAYMENTS_CONDITION,
            address(distributePaymentsCondition),
            1
        );
        nvmConfig.grantCondition(address(distributePaymentsCondition));
        vm.stopBroadcast();
        
        return (
            lockPaymentCondition,
            transferCreditsCondition,
            distributePaymentsCondition
        );
    }
}
