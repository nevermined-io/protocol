// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {FiatPaymentTemplate} from '../../contracts/agreements/FiatPaymentTemplate.sol';
import {FixedPaymentTemplate} from '../../contracts/agreements/FixedPaymentTemplate.sol';
import {DeployConfig} from './DeployConfig.sol';

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract DeployTemplates is Script, DeployConfig {
    function run(
        address ownerAddress,
        address nvmConfigAddress,
        address assetsRegistryAddress,
        address agreementsStoreAddress,
        address lockPaymentConditionAddress,
        address transferCreditsConditionAddress,
        address distributePaymentsConditionAddress,
        address fiatSettlementConditionAddress,
        address accessManagerAddress
    ) public returns (FixedPaymentTemplate, FiatPaymentTemplate) {
        console2.log('Deploying Templates with:');
        console2.log('\tOwner:', ownerAddress);
        console2.log('\tNVMConfig:', nvmConfigAddress);
        console2.log('\tAssetsRegistry:', assetsRegistryAddress);
        console2.log('\tAgreementsStore:', agreementsStoreAddress);
        console2.log('\tLockPaymentCondition:', lockPaymentConditionAddress);
        console2.log('\tTransferCreditsCondition:', transferCreditsConditionAddress);
        console2.log('\tDistributePaymentsCondition:', distributePaymentsConditionAddress);
        console2.log('\tFiatSettlementCondition:', fiatSettlementConditionAddress);
        console2.log('\tAccessManager:', accessManagerAddress);

        vm.startBroadcast(ownerAddress);

        // Deploy FixedPaymentTemplate
        FixedPaymentTemplate fixedPaymentTemplateImpl = new FixedPaymentTemplate();
        bytes memory fixedPaymentTemplateData = abi.encodeCall(
            FixedPaymentTemplate.initialize,
            (
                address(fixedPaymentTemplateImpl),
                accessManagerAddress,
                assetsRegistryAddress,
                agreementsStoreAddress,
                lockPaymentConditionAddress,
                transferCreditsConditionAddress,
                distributePaymentsConditionAddress
            )
        );
        FixedPaymentTemplate fixedPaymentTemplate =
            FixedPaymentTemplate(address(new ERC1967Proxy(address(fixedPaymentTemplateImpl), fixedPaymentTemplateData)));

        // Deploy FiatPaymentTemplate
        FiatPaymentTemplate fiatPaymentTemplateImpl = new FiatPaymentTemplate();
        bytes memory fiatPaymentTemplateData = abi.encodeCall(
            FiatPaymentTemplate.initialize,
            (
                address(fiatPaymentTemplateImpl),
                accessManagerAddress,
                assetsRegistryAddress,
                agreementsStoreAddress,
                fiatSettlementConditionAddress,
                transferCreditsConditionAddress
            )
        );
        FiatPaymentTemplate fiatPaymentTemplate =
            FiatPaymentTemplate(address(new ERC1967Proxy(address(fiatPaymentTemplateImpl), fiatPaymentTemplateData)));

        vm.stopBroadcast();

        return (fixedPaymentTemplate, fiatPaymentTemplate);
    }
}
