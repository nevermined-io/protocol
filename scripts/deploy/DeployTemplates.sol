// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {AgreementsStore} from '../../contracts/agreements/AgreementsStore.sol';
import {FiatPaymentTemplate} from '../../contracts/agreements/FiatPaymentTemplate.sol';
import {FixedPaymentTemplate} from '../../contracts/agreements/FixedPaymentTemplate.sol';

import {DistributePaymentsCondition} from '../../contracts/conditions/DistributePaymentsCondition.sol';
import {FiatSettlementCondition} from '../../contracts/conditions/FiatSettlementCondition.sol';
import {LockPaymentCondition} from '../../contracts/conditions/LockPaymentCondition.sol';
import {TransferCreditsCondition} from '../../contracts/conditions/TransferCreditsCondition.sol';
import {IAsset} from '../../contracts/interfaces/IAsset.sol';
import {INVMConfig} from '../../contracts/interfaces/INVMConfig.sol';
import {DeployConfig} from './DeployConfig.sol';
import {Create2DeployUtils} from './common/Create2DeployUtils.sol';
import {UpgradeableContractDeploySalt} from './common/Types.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';

import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract DeployTemplates is Script, DeployConfig, Create2DeployUtils {
    error FixedPaymentTemplateDeployment_InvalidAuthority(address authority);
    error FiatPaymentTemplateDeployment_InvalidAuthority(address authority);
    error InvalidSalt();

    function run(
        address ownerAddress,
        INVMConfig nvmConfigAddress,
        IAsset assetsRegistryAddress,
        AgreementsStore agreementsStoreAddress,
        LockPaymentCondition lockPaymentConditionAddress,
        TransferCreditsCondition transferCreditsConditionAddress,
        DistributePaymentsCondition distributePaymentsConditionAddress,
        FiatSettlementCondition fiatSettlementConditionAddress,
        IAccessManager accessManagerAddress,
        UpgradeableContractDeploySalt memory fixedPaymentTemplateSalt,
        UpgradeableContractDeploySalt memory fiatPaymentTemplateSalt,
        bool revertIfAlreadyDeployed
    ) public returns (FixedPaymentTemplate, FiatPaymentTemplate) {
        // Check for zero salts
        require(
            fixedPaymentTemplateSalt.implementationSalt != bytes32(0)
                && fiatPaymentTemplateSalt.implementationSalt != bytes32(0),
            InvalidSalt()
        );

        console2.log('Deploying Templates with:');
        console2.log('\tOwner:', ownerAddress);
        console2.log('\tNVMConfig:', address(nvmConfigAddress));
        console2.log('\tAssetsRegistry:', address(assetsRegistryAddress));
        console2.log('\tAgreementsStore:', address(agreementsStoreAddress));
        console2.log('\tLockPaymentCondition:', address(lockPaymentConditionAddress));
        console2.log('\tTransferCreditsCondition:', address(transferCreditsConditionAddress));
        console2.log('\tDistributePaymentsCondition:', address(distributePaymentsConditionAddress));
        console2.log('\tFiatSettlementCondition:', address(fiatSettlementConditionAddress));
        console2.log('\tAccessManager:', address(accessManagerAddress));

        vm.startBroadcast(ownerAddress);

        // Deploy FixedPaymentTemplate
        FixedPaymentTemplate fixedPaymentTemplate = deployFixedPaymentTemplate(
            nvmConfigAddress,
            accessManagerAddress,
            assetsRegistryAddress,
            agreementsStoreAddress,
            lockPaymentConditionAddress,
            transferCreditsConditionAddress,
            distributePaymentsConditionAddress,
            fixedPaymentTemplateSalt,
            revertIfAlreadyDeployed
        );

        // Deploy FiatPaymentTemplate
        FiatPaymentTemplate fiatPaymentTemplate = deployFiatPaymentTemplate(
            nvmConfigAddress,
            accessManagerAddress,
            assetsRegistryAddress,
            agreementsStoreAddress,
            fiatSettlementConditionAddress,
            transferCreditsConditionAddress,
            fiatPaymentTemplateSalt,
            revertIfAlreadyDeployed
        );

        vm.stopBroadcast();

        return (fixedPaymentTemplate, fiatPaymentTemplate);
    }

    function deployFixedPaymentTemplate(
        INVMConfig nvmConfigAddress,
        IAccessManager accessManagerAddress,
        IAsset assetsRegistryAddress,
        AgreementsStore agreementsStoreAddress,
        LockPaymentCondition lockPaymentConditionAddress,
        TransferCreditsCondition transferCreditsConditionAddress,
        DistributePaymentsCondition distributePaymentsConditionAddress,
        UpgradeableContractDeploySalt memory fixedPaymentTemplateSalt,
        bool revertIfAlreadyDeployed
    ) public returns (FixedPaymentTemplate fixedPaymentTemplate) {
        // Check for zero salt
        require(fixedPaymentTemplateSalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy FixedPaymentTemplate Implementation
        console2.log('Deploying FixedPaymentTemplate Implementation');
        (address fixedPaymentTemplateImpl,) = deployWithSanityChecks(
            fixedPaymentTemplateSalt.implementationSalt,
            type(FixedPaymentTemplate).creationCode,
            revertIfAlreadyDeployed
        );
        console2.log('FixedPaymentTemplate Implementation deployed at:', address(fixedPaymentTemplateImpl));

        // Deploy FixedPaymentTemplate Proxy
        console2.log('Deploying FixedPaymentTemplate Proxy');
        bytes memory fixedPaymentTemplateInitData = abi.encodeCall(
            FixedPaymentTemplate.initialize,
            (
                nvmConfigAddress,
                accessManagerAddress,
                assetsRegistryAddress,
                agreementsStoreAddress,
                lockPaymentConditionAddress,
                transferCreditsConditionAddress,
                distributePaymentsConditionAddress
            )
        );
        (address fixedPaymentTemplateProxy,) = deployWithSanityChecks(
            fixedPaymentTemplateSalt.proxySalt,
            getERC1967ProxyCreationCode(address(fixedPaymentTemplateImpl), fixedPaymentTemplateInitData),
            revertIfAlreadyDeployed
        );
        fixedPaymentTemplate = FixedPaymentTemplate(fixedPaymentTemplateProxy);
        console2.log('FixedPaymentTemplate Proxy deployed at:', address(fixedPaymentTemplate));

        // Verify deployment
        require(
            fixedPaymentTemplate.authority() == address(accessManagerAddress),
            FixedPaymentTemplateDeployment_InvalidAuthority(address(fixedPaymentTemplate.authority()))
        );
    }

    function deployFiatPaymentTemplate(
        INVMConfig nvmConfigAddress,
        IAccessManager accessManagerAddress,
        IAsset assetsRegistryAddress,
        AgreementsStore agreementsStoreAddress,
        FiatSettlementCondition fiatSettlementConditionAddress,
        TransferCreditsCondition transferCreditsConditionAddress,
        UpgradeableContractDeploySalt memory fiatPaymentTemplateSalt,
        bool revertIfAlreadyDeployed
    ) public returns (FiatPaymentTemplate fiatPaymentTemplate) {
        // Check for zero salt
        require(fiatPaymentTemplateSalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy FiatPaymentTemplate Implementation
        console2.log('Deploying FiatPaymentTemplate Implementation');
        (address fiatPaymentTemplateImpl,) = deployWithSanityChecks(
            fiatPaymentTemplateSalt.implementationSalt, type(FiatPaymentTemplate).creationCode, revertIfAlreadyDeployed
        );
        console2.log('FiatPaymentTemplate Implementation deployed at:', address(fiatPaymentTemplateImpl));

        // Deploy FiatPaymentTemplate Proxy
        console2.log('Deploying FiatPaymentTemplate Proxy');
        bytes memory fiatPaymentTemplateInitData = abi.encodeCall(
            FiatPaymentTemplate.initialize,
            (
                nvmConfigAddress,
                accessManagerAddress,
                assetsRegistryAddress,
                agreementsStoreAddress,
                fiatSettlementConditionAddress,
                transferCreditsConditionAddress
            )
        );
        (address fiatPaymentTemplateProxy,) = deployWithSanityChecks(
            fiatPaymentTemplateSalt.proxySalt,
            getERC1967ProxyCreationCode(address(fiatPaymentTemplateImpl), fiatPaymentTemplateInitData),
            revertIfAlreadyDeployed
        );
        fiatPaymentTemplate = FiatPaymentTemplate(fiatPaymentTemplateProxy);
        console2.log('FiatPaymentTemplate Proxy deployed at:', address(fiatPaymentTemplate));

        // Verify deployment
        require(
            fiatPaymentTemplate.authority() == address(accessManagerAddress),
            FiatPaymentTemplateDeployment_InvalidAuthority(address(fiatPaymentTemplate.authority()))
        );
    }
}
