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
        // Derive keys from mnemonic
        string memory mnemonic = vm.envString("MNEMONIC");
        uint256 ownerIndex = vm.envUint("OWNER_INDEX");
        uint256 governorIndex = vm.envUint("GOVERNOR_INDEX");
        uint256 ownerKey = uint256(vm.createKey(mnemonic, ownerIndex));
        uint256 governorKey = uint256(vm.createKey(mnemonic, governorIndex));
        INVMConfig nvmConfig = INVMConfig(nvmConfigAddress);
        
        // Deploy LockPaymentCondition with TokenUtils library
        vm.startBroadcast(ownerKey);
        LockPaymentCondition lockPaymentCondition = new LockPaymentCondition();
        lockPaymentCondition.initialize(
            nvmConfigAddress,
            assetsRegistryAddress,
            agreementsStoreAddress,
            paymentsVaultAddress
        );
        vm.stopBroadcast();
        
        // Register LockPaymentCondition in NVMConfig (called by governor)
        // Using direct call to NVMConfig since registerContract is not in the interface
        vm.startBroadcast(governorKey);
        (bool success1, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "registerContract(bytes32,address,uint256)",
                Constants.HASH_LOCKPAYMENT_CONDITION,
                address(lockPaymentCondition),
                1
            )
        );
        require(success1, "Failed to register LockPaymentCondition");
        
        // Using direct call for grantCondition since it's not in the interface
        (bool success2, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "grantCondition(address)",
                address(lockPaymentCondition)
            )
        );
        require(success2, "Failed to grant condition role to LockPaymentCondition");
        vm.stopBroadcast();
        
        // Deploy TransferCreditsCondition
        vm.startBroadcast(ownerKey);
        TransferCreditsCondition transferCreditsCondition = new TransferCreditsCondition();
        transferCreditsCondition.initialize(
            nvmConfigAddress,
            assetsRegistryAddress,
            agreementsStoreAddress
        );
        vm.stopBroadcast();
        
        // Register TransferCreditsCondition in NVMConfig (called by governor)
        // Using direct call to NVMConfig since registerContract is not in the interface
        vm.startBroadcast(governorKey);
        (bool success3, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "registerContract(bytes32,address,uint256)",
                Constants.HASH_TRANSFERCREDITS_CONDITION,
                address(transferCreditsCondition),
                1
            )
        );
        require(success3, "Failed to register TransferCreditsCondition");
        
        // Using direct call for grantCondition since it's not in the interface
        (bool success4, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "grantCondition(address)",
                address(transferCreditsCondition)
            )
        );
        require(success4, "Failed to grant condition role to TransferCreditsCondition");
        vm.stopBroadcast();
        
        // Deploy DistributePaymentsCondition with TokenUtils library
        vm.startBroadcast(ownerKey);
        DistributePaymentsCondition distributePaymentsCondition = new DistributePaymentsCondition();
        distributePaymentsCondition.initialize(
            nvmConfigAddress,
            assetsRegistryAddress,
            agreementsStoreAddress,
            paymentsVaultAddress
        );
        vm.stopBroadcast();
        
        // Register DistributePaymentsCondition in NVMConfig (called by governor)
        // Using direct call to NVMConfig since registerContract is not in the interface
        vm.startBroadcast(governorKey);
        (bool success5, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "registerContract(bytes32,address,uint256)",
                Constants.HASH_DISTRIBUTEPAYMENTS_CONDITION,
                address(distributePaymentsCondition),
                1
            )
        );
        require(success5, "Failed to register DistributePaymentsCondition");
        
        // Using direct call for grantCondition since it's not in the interface
        (bool success6, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "grantCondition(address)",
                address(distributePaymentsCondition)
            )
        );
        require(success6, "Failed to grant condition role to DistributePaymentsCondition");
        vm.stopBroadcast();
        
        return (
            lockPaymentCondition,
            transferCreditsCondition,
            distributePaymentsCondition
        );
    }
}
