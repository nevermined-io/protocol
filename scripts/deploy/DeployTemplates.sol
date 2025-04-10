// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {FiatPaymentTemplate} from '../../contracts/agreements/FiatPaymentTemplate.sol';
import {FixedPaymentTemplate} from '../../contracts/agreements/FixedPaymentTemplate.sol';
import {DeployConfig} from './DeployConfig.sol';

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

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
        console.log('Deploying Templates with:');
        console.log('\tOwner:', ownerAddress);
        console.log('\tNVMConfig:', nvmConfigAddress);
        console.log('\tAssetsRegistry:', assetsRegistryAddress);
        console.log('\tAgreementsStore:', agreementsStoreAddress);
        console.log('\tLockPaymentCondition:', lockPaymentConditionAddress);
        console.log('\tTransferCreditsCondition:', transferCreditsConditionAddress);
        console.log('\tDistributePaymentsCondition:', distributePaymentsConditionAddress);
        console.log('\tFiatSettlementCondition:', fiatSettlementConditionAddress);
        console.log('\tAccessManager:', accessManagerAddress);

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
