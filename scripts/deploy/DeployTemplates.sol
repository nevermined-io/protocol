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

import {Script} from 'lib/forge-std/src/Script.sol';
import {console2} from 'lib/forge-std/src/console2.sol';

contract DeployTemplates is DeployConfig, Create2DeployUtils {
    error FixedPaymentTemplateDeployment_InvalidAuthority(address authority);
    error FiatPaymentTemplateDeployment_InvalidAuthority(address authority);
    error InvalidSalt();

    struct DeployTemplatesParams {
        address ownerAddress;
        INVMConfig nvmConfigAddress;
        IAsset assetsRegistryAddress;
        AgreementsStore agreementsStoreAddress;
        LockPaymentCondition lockPaymentConditionAddress;
        TransferCreditsCondition transferCreditsConditionAddress;
        DistributePaymentsCondition distributePaymentsConditionAddress;
        FiatSettlementCondition fiatSettlementConditionAddress;
        IAccessManager accessManagerAddress;
        UpgradeableContractDeploySalt fixedPaymentTemplateSalt;
        UpgradeableContractDeploySalt fiatPaymentTemplateSalt;
        bool revertIfAlreadyDeployed;
    }

    function run(DeployTemplatesParams memory params) public returns (FixedPaymentTemplate, FiatPaymentTemplate) {
        // Check for zero salts
        require(
            params.fixedPaymentTemplateSalt.implementationSalt != bytes32(0)
                && params.fiatPaymentTemplateSalt.implementationSalt != bytes32(0),
            InvalidSalt()
        );

        if (debug) {
            console2.log('Deploying Templates with:');
            console2.log('\tOwner:', params.ownerAddress);
            console2.log('\tNVMConfig:', address(params.nvmConfigAddress));
            console2.log('\tAssetsRegistry:', address(params.assetsRegistryAddress));
            console2.log('\tAgreementsStore:', address(params.agreementsStoreAddress));
            console2.log('\tLockPaymentCondition:', address(params.lockPaymentConditionAddress));
            console2.log('\tTransferCreditsCondition:', address(params.transferCreditsConditionAddress));
            console2.log('\tDistributePaymentsCondition:', address(params.distributePaymentsConditionAddress));
            console2.log('\tFiatSettlementCondition:', address(params.fiatSettlementConditionAddress));
            console2.log('\tAccessManager:', address(params.accessManagerAddress));
        }
        vm.startBroadcast(params.ownerAddress);

        // Deploy FixedPaymentTemplate
        FixedPaymentTemplate fixedPaymentTemplate = deployFixedPaymentTemplate(
            params.nvmConfigAddress,
            params.accessManagerAddress,
            params.assetsRegistryAddress,
            params.agreementsStoreAddress,
            params.lockPaymentConditionAddress,
            params.transferCreditsConditionAddress,
            params.distributePaymentsConditionAddress,
            params.fixedPaymentTemplateSalt,
            params.revertIfAlreadyDeployed
        );

        // Deploy FiatPaymentTemplate
        FiatPaymentTemplate fiatPaymentTemplate = deployFiatPaymentTemplate(
            params.nvmConfigAddress,
            params.accessManagerAddress,
            params.assetsRegistryAddress,
            params.agreementsStoreAddress,
            params.fiatSettlementConditionAddress,
            params.transferCreditsConditionAddress,
            params.fiatPaymentTemplateSalt,
            params.revertIfAlreadyDeployed
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
        if (debug) console2.log('Deploying FixedPaymentTemplate Implementation');
        (address fixedPaymentTemplateImpl,) = deployWithSanityChecks(
            fixedPaymentTemplateSalt.implementationSalt,
            type(FixedPaymentTemplate).creationCode,
            revertIfAlreadyDeployed
        );
        if (debug) console2.log('FixedPaymentTemplate Implementation deployed at:', address(fixedPaymentTemplateImpl));

        // Deploy FixedPaymentTemplate Proxy
        if (debug) console2.log('Deploying FixedPaymentTemplate Proxy');
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
        if (debug) console2.log('FixedPaymentTemplate Proxy deployed at:', address(fixedPaymentTemplate));

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
        if (debug) console2.log('Deploying FiatPaymentTemplate Implementation');
        (address fiatPaymentTemplateImpl,) = deployWithSanityChecks(
            fiatPaymentTemplateSalt.implementationSalt, type(FiatPaymentTemplate).creationCode, revertIfAlreadyDeployed
        );
        if (debug) console2.log('FiatPaymentTemplate Implementation deployed at:', address(fiatPaymentTemplateImpl));

        // Deploy FiatPaymentTemplate Proxy
        if (debug) console2.log('Deploying FiatPaymentTemplate Proxy');
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
        if (debug) console2.log('FiatPaymentTemplate Proxy deployed at:', address(fiatPaymentTemplate));

        // Verify deployment
        require(
            fiatPaymentTemplate.authority() == address(accessManagerAddress),
            FiatPaymentTemplateDeployment_InvalidAuthority(address(fiatPaymentTemplate.authority()))
        );
    }
}
