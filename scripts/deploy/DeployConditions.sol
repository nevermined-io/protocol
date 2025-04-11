// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {DistributePaymentsCondition} from '../../contracts/conditions/DistributePaymentsCondition.sol';
import {FiatSettlementCondition} from '../../contracts/conditions/FiatSettlementCondition.sol';
import {LockPaymentCondition} from '../../contracts/conditions/LockPaymentCondition.sol';
import {TransferCreditsCondition} from '../../contracts/conditions/TransferCreditsCondition.sol';
import {DeployConfig} from './DeployConfig.sol';

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract DeployConditions is Script, DeployConfig {
    function run(
        address ownerAddress,
        address nvmConfigAddress,
        address assetsRegistryAddress,
        address agreementsStoreAddress,
        address paymentsVaultAddress,
        address tokenUtilsAddress,
        address accessManagerAddress
    )
        public
        returns (LockPaymentCondition, TransferCreditsCondition, DistributePaymentsCondition, FiatSettlementCondition)
    {
        console2.log('Deploying Conditions with:');
        console2.log('\tOwner:', ownerAddress);
        console2.log('\tNVMConfig:', nvmConfigAddress);
        console2.log('\tAssetsRegistry:', assetsRegistryAddress);
        console2.log('\tAgreementsStore:', agreementsStoreAddress);
        console2.log('\tPaymentsVault:', paymentsVaultAddress);
        console2.log('\tTokenUtils:', tokenUtilsAddress);
        console2.log('\tAccessManager:', accessManagerAddress);

        vm.startBroadcast(ownerAddress);

        // Deploy LockPaymentCondition
        LockPaymentCondition lockPaymentConditionImpl = new LockPaymentCondition();
        bytes memory lockPaymentConditionData = abi.encodeCall(
            LockPaymentCondition.initialize,
            (
                nvmConfigAddress,
                accessManagerAddress,
                assetsRegistryAddress,
                agreementsStoreAddress,
                paymentsVaultAddress
            )
        );
        LockPaymentCondition lockPaymentCondition =
            LockPaymentCondition(address(new ERC1967Proxy(address(lockPaymentConditionImpl), lockPaymentConditionData)));

        // Deploy TransferCreditsCondition
        TransferCreditsCondition transferCreditsConditionImpl = new TransferCreditsCondition();
        bytes memory transferCreditsConditionData = abi.encodeCall(
            TransferCreditsCondition.initialize,
            (nvmConfigAddress, accessManagerAddress, assetsRegistryAddress, agreementsStoreAddress)
        );
        TransferCreditsCondition transferCreditsCondition = TransferCreditsCondition(
            address(new ERC1967Proxy(address(transferCreditsConditionImpl), transferCreditsConditionData))
        );

        // Deploy DistributePaymentsCondition
        DistributePaymentsCondition distributePaymentsConditionImpl = new DistributePaymentsCondition();
        bytes memory distributePaymentsConditionData = abi.encodeCall(
            DistributePaymentsCondition.initialize,
            (
                nvmConfigAddress,
                accessManagerAddress,
                assetsRegistryAddress,
                agreementsStoreAddress,
                paymentsVaultAddress
            )
        );
        DistributePaymentsCondition distributePaymentsCondition = DistributePaymentsCondition(
            address(new ERC1967Proxy(address(distributePaymentsConditionImpl), distributePaymentsConditionData))
        );

        // Deploy FiatSettlementCondition
        FiatSettlementCondition fiatSettlementConditionImpl = new FiatSettlementCondition();
        bytes memory fiatSettlementConditionData = abi.encodeCall(
            FiatSettlementCondition.initialize,
            (nvmConfigAddress, accessManagerAddress, assetsRegistryAddress, agreementsStoreAddress)
        );
        FiatSettlementCondition fiatSettlementCondition = FiatSettlementCondition(
            address(new ERC1967Proxy(address(fiatSettlementConditionImpl), fiatSettlementConditionData))
        );

        vm.stopBroadcast();

        return (lockPaymentCondition, transferCreditsCondition, distributePaymentsCondition, fiatSettlementCondition);
    }
}
