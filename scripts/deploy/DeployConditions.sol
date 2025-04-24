// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {DistributePaymentsCondition} from '../../contracts/conditions/DistributePaymentsCondition.sol';
import {FiatSettlementCondition} from '../../contracts/conditions/FiatSettlementCondition.sol';
import {LockPaymentCondition} from '../../contracts/conditions/LockPaymentCondition.sol';
import {TransferCreditsCondition} from '../../contracts/conditions/TransferCreditsCondition.sol';

import {IAgreement} from '../../contracts/interfaces/IAgreement.sol';
import {IAsset} from '../../contracts/interfaces/IAsset.sol';
import {INVMConfig} from '../../contracts/interfaces/INVMConfig.sol';
import {IVault} from '../../contracts/interfaces/IVault.sol';
import {DeployConfig} from './DeployConfig.sol';
import {Create2DeployUtils} from './common/Create2DeployUtils.sol';
import {UpgradeableContractDeploySalt} from './common/Types.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';
import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

contract DeployConditions is DeployConfig, Create2DeployUtils {
    error LockPaymentConditionDeployment_InvalidAuthority(address authority);
    error TransferCreditsConditionDeployment_InvalidAuthority(address authority);
    error DistributePaymentsConditionDeployment_InvalidAuthority(address authority);
    error FiatSettlementConditionDeployment_InvalidAuthority(address authority);
    error InvalidSalt();

    function run(
        address ownerAddress,
        INVMConfig nvmConfigAddress,
        IAsset assetsRegistryAddress,
        IAgreement agreementsStoreAddress,
        IVault paymentsVaultAddress,
        IAccessManager accessManagerAddress,
        UpgradeableContractDeploySalt memory lockPaymentConditionSalt,
        UpgradeableContractDeploySalt memory transferCreditsConditionSalt,
        UpgradeableContractDeploySalt memory distributePaymentsConditionSalt,
        UpgradeableContractDeploySalt memory fiatSettlementConditionSalt,
        bool revertIfAlreadyDeployed
    )
        public
        returns (
            LockPaymentCondition lockPaymentCondition,
            TransferCreditsCondition transferCreditsCondition,
            DistributePaymentsCondition distributePaymentsCondition,
            FiatSettlementCondition fiatSettlementCondition
        )
    {
        // Check for zero salts
        require(
            lockPaymentConditionSalt.implementationSalt != bytes32(0)
                && transferCreditsConditionSalt.implementationSalt != bytes32(0)
                && distributePaymentsConditionSalt.implementationSalt != bytes32(0)
                && fiatSettlementConditionSalt.implementationSalt != bytes32(0),
            InvalidSalt()
        );
        if (debug) {
            console2.log('Deploying Conditions with:');
            console2.log('\tOwner:', ownerAddress);
            console2.log('\tNVMConfig:', address(nvmConfigAddress));
            console2.log('\tAssetsRegistry:', address(assetsRegistryAddress));
            console2.log('\tAgreementsStore:', address(agreementsStoreAddress));
            console2.log('\tPaymentsVault:', address(paymentsVaultAddress));
            console2.log('\tAccessManager:', address(accessManagerAddress));
        }
        
        vm.startBroadcast(ownerAddress);

        // Deploy LockPaymentCondition
        lockPaymentCondition = deployLockPaymentCondition(
            nvmConfigAddress,
            accessManagerAddress,
            assetsRegistryAddress,
            agreementsStoreAddress,
            paymentsVaultAddress,
            lockPaymentConditionSalt,
            revertIfAlreadyDeployed
        );

        // Deploy TransferCreditsCondition
        transferCreditsCondition = deployTransferCreditsCondition(
            nvmConfigAddress,
            accessManagerAddress,
            assetsRegistryAddress,
            agreementsStoreAddress,
            transferCreditsConditionSalt,
            revertIfAlreadyDeployed
        );

        // Deploy DistributePaymentsCondition
        distributePaymentsCondition = deployDistributePaymentsCondition(
            nvmConfigAddress,
            accessManagerAddress,
            assetsRegistryAddress,
            agreementsStoreAddress,
            paymentsVaultAddress,
            distributePaymentsConditionSalt,
            revertIfAlreadyDeployed
        );

        // Deploy FiatSettlementCondition
        fiatSettlementCondition = deployFiatSettlementCondition(
            nvmConfigAddress,
            accessManagerAddress,
            assetsRegistryAddress,
            agreementsStoreAddress,
            fiatSettlementConditionSalt,
            revertIfAlreadyDeployed
        );

        vm.stopBroadcast();

        return (lockPaymentCondition, transferCreditsCondition, distributePaymentsCondition, fiatSettlementCondition);
    }

    function deployLockPaymentCondition(
        INVMConfig nvmConfigAddress,
        IAccessManager accessManagerAddress,
        IAsset assetsRegistryAddress,
        IAgreement agreementsStoreAddress,
        IVault paymentsVaultAddress,
        UpgradeableContractDeploySalt memory lockPaymentConditionSalt,
        bool revertIfAlreadyDeployed
    ) public returns (LockPaymentCondition lockPaymentCondition) {
        // Check for zero salt
        require(lockPaymentConditionSalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy LockPaymentCondition Implementation
        if (debug) console2.log('Deploying LockPaymentCondition Implementation');
        (address lockPaymentConditionImpl,) = deployWithSanityChecks(
            lockPaymentConditionSalt.implementationSalt,
            type(LockPaymentCondition).creationCode,
            revertIfAlreadyDeployed
        );
        if (debug) console2.log('LockPaymentCondition Implementation deployed at:', address(lockPaymentConditionImpl));

        // Deploy LockPaymentCondition Proxy
        if (debug) console2.log('Deploying LockPaymentCondition Proxy');
        bytes memory lockPaymentConditionInitData = abi.encodeCall(
            LockPaymentCondition.initialize,
            (
                nvmConfigAddress,
                accessManagerAddress,
                assetsRegistryAddress,
                agreementsStoreAddress,
                paymentsVaultAddress
            )
        );
        (address lockPaymentConditionProxy,) = deployWithSanityChecks(
            lockPaymentConditionSalt.proxySalt,
            getERC1967ProxyCreationCode(address(lockPaymentConditionImpl), lockPaymentConditionInitData),
            revertIfAlreadyDeployed
        );
        lockPaymentCondition = LockPaymentCondition(lockPaymentConditionProxy);
        if (debug) console2.log('LockPaymentCondition Proxy deployed at:', address(lockPaymentCondition));

        // Verify deployment
        require(
            lockPaymentCondition.authority() == address(accessManagerAddress),
            LockPaymentConditionDeployment_InvalidAuthority(address(lockPaymentCondition.authority()))
        );
    }

    function deployTransferCreditsCondition(
        INVMConfig nvmConfigAddress,
        IAccessManager accessManagerAddress,
        IAsset assetsRegistryAddress,
        IAgreement agreementsStoreAddress,
        UpgradeableContractDeploySalt memory transferCreditsConditionSalt,
        bool revertIfAlreadyDeployed
    ) public returns (TransferCreditsCondition transferCreditsCondition) {
        // Check for zero salt
        require(transferCreditsConditionSalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy TransferCreditsCondition Implementation
        if (debug) console2.log('Deploying TransferCreditsCondition Implementation');
        (address transferCreditsConditionImpl,) = deployWithSanityChecks(
            transferCreditsConditionSalt.implementationSalt,
            type(TransferCreditsCondition).creationCode,
            revertIfAlreadyDeployed
        );
        if (debug) console2.log('TransferCreditsCondition Implementation deployed at:', address(transferCreditsConditionImpl));

        // Deploy TransferCreditsCondition Proxy
        if (debug) console2.log('Deploying TransferCreditsCondition Proxy');
        bytes memory transferCreditsConditionInitData = abi.encodeCall(
            TransferCreditsCondition.initialize,
            (nvmConfigAddress, accessManagerAddress, assetsRegistryAddress, agreementsStoreAddress)
        );
        (address transferCreditsConditionProxy,) = deployWithSanityChecks(
            transferCreditsConditionSalt.proxySalt,
            getERC1967ProxyCreationCode(address(transferCreditsConditionImpl), transferCreditsConditionInitData),
            revertIfAlreadyDeployed
        );
        transferCreditsCondition = TransferCreditsCondition(transferCreditsConditionProxy);
        if (debug) console2.log('TransferCreditsCondition Proxy deployed at:', address(transferCreditsCondition));

        // Verify deployment
        require(
            transferCreditsCondition.authority() == address(accessManagerAddress),
            TransferCreditsConditionDeployment_InvalidAuthority(address(transferCreditsCondition.authority()))
        );
    }

    function deployDistributePaymentsCondition(
        INVMConfig nvmConfigAddress,
        IAccessManager accessManagerAddress,
        IAsset assetsRegistryAddress,
        IAgreement agreementsStoreAddress,
        IVault paymentsVaultAddress,
        UpgradeableContractDeploySalt memory distributePaymentsConditionSalt,
        bool revertIfAlreadyDeployed
    ) public returns (DistributePaymentsCondition distributePaymentsCondition) {
        // Check for zero salt
        require(distributePaymentsConditionSalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy DistributePaymentsCondition Implementation
        if (debug) console2.log('Deploying DistributePaymentsCondition Implementation');
        (address distributePaymentsConditionImpl,) = deployWithSanityChecks(
            distributePaymentsConditionSalt.implementationSalt,
            type(DistributePaymentsCondition).creationCode,
            revertIfAlreadyDeployed
        );
        if (debug) console2.log(
            'DistributePaymentsCondition Implementation deployed at:', address(distributePaymentsConditionImpl)
        );

        // Deploy DistributePaymentsCondition Proxy
        if (debug) console2.log('Deploying DistributePaymentsCondition Proxy');
        bytes memory distributePaymentsConditionInitData = abi.encodeCall(
            DistributePaymentsCondition.initialize,
            (
                nvmConfigAddress,
                accessManagerAddress,
                assetsRegistryAddress,
                agreementsStoreAddress,
                paymentsVaultAddress
            )
        );
        (address distributePaymentsConditionProxy,) = deployWithSanityChecks(
            distributePaymentsConditionSalt.proxySalt,
            getERC1967ProxyCreationCode(address(distributePaymentsConditionImpl), distributePaymentsConditionInitData),
            revertIfAlreadyDeployed
        );
        distributePaymentsCondition = DistributePaymentsCondition(distributePaymentsConditionProxy);
        if (debug) console2.log('DistributePaymentsCondition Proxy deployed at:', address(distributePaymentsCondition));

        // Verify deployment
        require(
            distributePaymentsCondition.authority() == address(accessManagerAddress),
            DistributePaymentsConditionDeployment_InvalidAuthority(address(distributePaymentsCondition.authority()))
        );
    }

    function deployFiatSettlementCondition(
        INVMConfig nvmConfigAddress,
        IAccessManager accessManagerAddress,
        IAsset assetsRegistryAddress,
        IAgreement agreementsStoreAddress,
        UpgradeableContractDeploySalt memory fiatSettlementConditionSalt,
        bool revertIfAlreadyDeployed
    ) public returns (FiatSettlementCondition fiatSettlementCondition) {
        // Check for zero salt
        require(fiatSettlementConditionSalt.implementationSalt != bytes32(0), InvalidSalt());

        // Deploy FiatSettlementCondition Implementation
        if (debug) console2.log('Deploying FiatSettlementCondition Implementation');
        (address fiatSettlementConditionImpl,) = deployWithSanityChecks(
            fiatSettlementConditionSalt.implementationSalt,
            type(FiatSettlementCondition).creationCode,
            revertIfAlreadyDeployed
        );
        if (debug) console2.log('FiatSettlementCondition Implementation deployed at:', address(fiatSettlementConditionImpl));

        // Deploy FiatSettlementCondition Proxy
        if (debug) console2.log('Deploying FiatSettlementCondition Proxy');
        bytes memory fiatSettlementConditionInitData = abi.encodeCall(
            FiatSettlementCondition.initialize,
            (nvmConfigAddress, accessManagerAddress, assetsRegistryAddress, agreementsStoreAddress)
        );
        (address fiatSettlementConditionProxy,) = deployWithSanityChecks(
            fiatSettlementConditionSalt.proxySalt,
            getERC1967ProxyCreationCode(address(fiatSettlementConditionImpl), fiatSettlementConditionInitData),
            revertIfAlreadyDeployed
        );
        fiatSettlementCondition = FiatSettlementCondition(fiatSettlementConditionProxy);
        if (debug) console2.log('FiatSettlementCondition Proxy deployed at:', address(fiatSettlementCondition));

        // Verify deployment
        require(
            fiatSettlementCondition.authority() == address(accessManagerAddress),
            FiatSettlementConditionDeployment_InvalidAuthority(address(fiatSettlementCondition.authority()))
        );
    }
}
