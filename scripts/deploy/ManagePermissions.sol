// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import {AssetsRegistry} from '../../contracts/AssetsRegistry.sol';
import {NVMConfig} from '../../contracts/NVMConfig.sol';
import {PaymentsVault} from '../../contracts/PaymentsVault.sol';
import {AgreementsStore} from '../../contracts/agreements/AgreementsStore.sol';
import {FiatPaymentTemplate} from '../../contracts/agreements/FiatPaymentTemplate.sol';
import {FixedPaymentTemplate} from '../../contracts/agreements/FixedPaymentTemplate.sol';
import '../../contracts/common/Roles.sol';
import {DistributePaymentsCondition} from '../../contracts/conditions/DistributePaymentsCondition.sol';
import {DistributePaymentsCondition} from '../../contracts/conditions/DistributePaymentsCondition.sol';
import {FiatSettlementCondition} from '../../contracts/conditions/FiatSettlementCondition.sol';
import {LockPaymentCondition} from '../../contracts/conditions/LockPaymentCondition.sol';
import {TransferCreditsCondition} from '../../contracts/conditions/TransferCreditsCondition.sol';
import {INVMConfig} from '../../contracts/interfaces/INVMConfig.sol';
import {NFT1155Credits} from '../../contracts/token/NFT1155Credits.sol';

import {NFT1155ExpirableCredits} from '../../contracts/token/NFT1155ExpirableCredits.sol';
import {Constants} from '../../scripts/Constants.sol';
import {DeployConfig} from './DeployConfig.sol';

import './common/ArrayUtils.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {AccessManager} from '@openzeppelin/contracts/access/manager/AccessManager.sol';
import {Script} from 'lib/forge-std/src/Script.sol';
import {console2} from 'lib/forge-std/src/console2.sol';

contract ManagePermissions is Script, DeployConfig {
    uint32 UPGRADE_DELAY = 1 days;

    struct Config {
        address owner;
        address upgrader;
        address governor;
        NVMConfig nvmConfig;
        AssetsRegistry assetsRegistry;
        AgreementsStore agreementsStore;
        PaymentsVault paymentsVault;
        NFT1155Credits nftCredits;
        NFT1155ExpirableCredits nftExpirableCredits;
        LockPaymentCondition lockPaymentCondition;
        DistributePaymentsCondition distributePaymentsCondition;
        TransferCreditsCondition transferCreditsCondition;
        FiatSettlementCondition fiatSettlementCondition;
        FixedPaymentTemplate fixedPaymentTemplate;
        FiatPaymentTemplate fiatPaymentTemplate;
        AccessManager accessManager;
    }

    function run(Config memory config) public {
        console2.log('Managing permissions for contracts...');

        vm.startBroadcast(config.owner);

        // Grant and configure upgrader role
        _grantUpgraderRole(config.upgrader, config.accessManager);
        _configureUpgradeRole(
            toArray(
                address(config.nvmConfig),
                address(config.agreementsStore),
                address(config.assetsRegistry),
                address(config.paymentsVault),
                address(config.nftCredits),
                address(config.nftExpirableCredits)
            ),
            config.accessManager
        );

        // Grant and configure governor role
        _grantGovernorRole(config.governor, config.accessManager);
        _configureGovernorRole(config.accessManager, config.nvmConfig);
        _grantInfraAdminRole(config.governor, config.accessManager); // we grant the infra admin role to the governor

        // Grant and configure deposit role
        _grantDepositRole(config.lockPaymentCondition, config.accessManager);
        _configureDepositRole(config.paymentsVault, config.accessManager);

        // Grant and configure withdraw role
        _grantWithdrawRole(config.distributePaymentsCondition, config.accessManager);
        _configureWithdrawRole(config.paymentsVault, config.accessManager);

        // Grant and configure template roles
        _grantTemplateRoles(
            toArray(address(config.fixedPaymentTemplate), address(config.fiatPaymentTemplate)), config.accessManager
        );
        _configureTemplateRoles(
            config.agreementsStore,
            config.distributePaymentsCondition,
            config.fiatSettlementCondition,
            config.lockPaymentCondition,
            config.transferCreditsCondition,
            config.accessManager
        );

        // Grant and configure condition status updater role
        _grantConditionStatusUpdaterRole(
            toArray(
                address(config.lockPaymentCondition),
                address(config.transferCreditsCondition),
                address(config.distributePaymentsCondition),
                address(config.fiatSettlementCondition)
            ),
            config.accessManager
        );
        _configureConditionStatusUpdaterRole(config.agreementsStore, config.accessManager);

        // Grant condition role
        _grantConditionRole(
            toArray(
                address(config.lockPaymentCondition),
                address(config.transferCreditsCondition),
                address(config.distributePaymentsCondition),
                address(config.fiatSettlementCondition)
            ),
            config.accessManager
        );

        // Grant and configure credits minter role
        _grantCreditsMinterRole(config.transferCreditsCondition, config.accessManager);
        _configureCreditsMinterRole(config.nftCredits, config.nftExpirableCredits, config.accessManager);

        // Configure credits burner role
        _configureCreditsBurnerRole(config.nftCredits, config.nftExpirableCredits, config.accessManager);

        // Transfer role admins to governor
        _configureRoleAdmins(config.accessManager);

        vm.stopBroadcast();

        console2.log('Permissions configured successfully');
    }

    function _configureRoleAdmins(AccessManager accessManager) internal {
        console2.log('Setting up role admins');

        console2.log('Making governor the admin of the CONTRACT_TEMPLATE_ROLE');
        accessManager.setRoleAdmin(CONTRACT_TEMPLATE_ROLE, GOVERNOR_ROLE);

        console2.log('Making governor the admin of the CONTRACT_CONDITION_ROLE');
        accessManager.setRoleAdmin(CONTRACT_CONDITION_ROLE, GOVERNOR_ROLE);

        console2.log('Making governor the admin of the UPDATE_CONDITION_STATUS_ROLE');
        accessManager.setRoleAdmin(UPDATE_CONDITION_STATUS_ROLE, GOVERNOR_ROLE);
    }

    function _grantDepositRole(LockPaymentCondition lockPaymentCondition, AccessManager accessManager) internal {
        console2.log('Granting deposit role to lock payment condition ', address(lockPaymentCondition));

        accessManager.grantRole(DEPOSITOR_ROLE, address(lockPaymentCondition), 0);
    }

    function _grantWithdrawRole(DistributePaymentsCondition distributePaymentsCondition, AccessManager accessManager)
        internal
    {
        console2.log('Granting withdraw role to distribute payments condition ', address(distributePaymentsCondition));

        accessManager.grantRole(WITHDRAW_ROLE, address(distributePaymentsCondition), 0);
    }

    function _grantGovernorRole(address governor, AccessManager accessManager) internal {
        console2.log('Granting governor role to governor ', governor);

        accessManager.grantRole(GOVERNOR_ROLE, governor, 0);
    }

    function _grantInfraAdminRole(address roleReceiver, AccessManager accessManager) internal {
        console2.log('Granting infra admin role to ', roleReceiver);

        accessManager.grantRole(NVM_INFRA_ADMIN_ROLE, roleReceiver, 0);
    }

    function _grantUpgraderRole(address upgrader, AccessManager accessManager) internal {
        console2.log('Granting upgrader role to upgrader ', upgrader);

        accessManager.grantRole(UPGRADE_ROLE, upgrader, UPGRADE_DELAY);
    }

    function _grantTemplateRoles(address[] memory templates, AccessManager accessManager) internal {
        for (uint256 i = 0; i < templates.length; i++) {
            console2.log('Granting template role to template ', templates[i]);
            accessManager.grantRole(CONTRACT_TEMPLATE_ROLE, templates[i], 0);
        }
    }

    function _grantConditionStatusUpdaterRole(address[] memory templatesAndConditions, AccessManager accessManager)
        internal
    {
        for (uint256 i = 0; i < templatesAndConditions.length; i++) {
            console2.log(
                'Granting condition status updater role to condition status updater ', templatesAndConditions[i]
            );

            accessManager.grantRole(UPDATE_CONDITION_STATUS_ROLE, templatesAndConditions[i], 0);
        }
    }

    function _grantConditionRole(address[] memory templatesAndConditions, AccessManager accessManager) internal {
        for (uint256 i = 0; i < templatesAndConditions.length; i++) {
            console2.log(
                'Granting condition status updater role to condition status updater ', templatesAndConditions[i]
            );
            accessManager.grantRole(CONTRACT_CONDITION_ROLE, templatesAndConditions[i], 0);
        }
    }

    function _grantCreditsMinterRole(TransferCreditsCondition transferCreditsCondition, AccessManager accessManager)
        internal
    {
        console2.log('Granting credits minter role to transfer credits condition ', address(transferCreditsCondition));

        accessManager.grantRole(CREDITS_MINTER_ROLE, address(transferCreditsCondition), 0);
    }

    function _configureUpgradeRole(address[] memory contracts, AccessManager accessManager) internal {
        for (uint256 i = 0; i < contracts.length; i++) {
            console2.log('Setting Upgrade Role for contract ', contracts[i]);
            accessManager.setTargetFunctionRole(
                contracts[i], toArray(UUPSUpgradeable.upgradeToAndCall.selector), UPGRADE_ROLE
            );
        }
    }

    function _configureGovernorRole(AccessManager accessManager, NVMConfig nvmConfig) internal {
        console2.log('Setting Governor Role for setters in NVMConfig');

        accessManager.setTargetFunctionRole(
            address(nvmConfig),
            toArray(
                NVMConfig.setNetworkFees.selector, NVMConfig.setParameter.selector, NVMConfig.disableParameter.selector
            ),
            GOVERNOR_ROLE
        );
    }

    function _configureDepositRole(PaymentsVault paymentsVault, AccessManager accessManager) internal {
        console2.log('Setting Deposit Role for setters in PaymentsVault');

        accessManager.setTargetFunctionRole(
            address(paymentsVault),
            toArray(PaymentsVault.depositNativeToken.selector, PaymentsVault.depositERC20.selector),
            DEPOSITOR_ROLE
        );
    }

    function _configureWithdrawRole(PaymentsVault paymentsVault, AccessManager accessManager) internal {
        console2.log('Setting Withdraw Role for setters in PaymentsVault');

        accessManager.setTargetFunctionRole(
            address(paymentsVault),
            toArray(PaymentsVault.withdrawNativeToken.selector, PaymentsVault.withdrawERC20.selector),
            WITHDRAW_ROLE
        );
    }

    function _configureTemplateRoles(
        AgreementsStore agreementsStore,
        DistributePaymentsCondition distributePaymentsCondition,
        FiatSettlementCondition fiatSettlementCondition,
        LockPaymentCondition lockPaymentCondition,
        TransferCreditsCondition transferCreditsCondition,
        AccessManager accessManager
    ) internal {
        console2.log('Setting Template role for fulfill() in condition contracts');

        accessManager.setTargetFunctionRole(
            address(agreementsStore), toArray(AgreementsStore.register.selector), CONTRACT_TEMPLATE_ROLE
        );
        accessManager.setTargetFunctionRole(
            address(distributePaymentsCondition),
            toArray(DistributePaymentsCondition.fulfill.selector),
            CONTRACT_TEMPLATE_ROLE
        );
        accessManager.setTargetFunctionRole(
            address(fiatSettlementCondition), toArray(FiatSettlementCondition.fulfill.selector), CONTRACT_TEMPLATE_ROLE
        );
        accessManager.setTargetFunctionRole(
            address(lockPaymentCondition), toArray(LockPaymentCondition.fulfill.selector), CONTRACT_TEMPLATE_ROLE
        );
        accessManager.setTargetFunctionRole(
            address(transferCreditsCondition),
            toArray(TransferCreditsCondition.fulfill.selector),
            CONTRACT_TEMPLATE_ROLE
        );
    }

    function _configureConditionStatusUpdaterRole(AgreementsStore agreementsStore, AccessManager accessManager)
        internal
    {
        console2.log('Setting Condition Status Updater Role for updateConditionStatus() in AgreementsStore');

        accessManager.setTargetFunctionRole(
            address(agreementsStore),
            toArray(AgreementsStore.updateConditionStatus.selector),
            UPDATE_CONDITION_STATUS_ROLE
        );
    }

    function _configureCreditsMinterRole(
        NFT1155Credits nftCredits,
        NFT1155ExpirableCredits nftExpirableCredits,
        AccessManager accessManager
    ) internal {
        console2.log('Setting Credits Minter Role for mintBatch() in NFT1155Credits and NFT1155ExpirableCredits');

        accessManager.setTargetFunctionRole(
            address(nftCredits), toArray(NFT1155Credits.mintBatch.selector), CREDITS_MINTER_ROLE
        );
        accessManager.setTargetFunctionRole(
            address(nftExpirableCredits), toArray(NFT1155Credits.mintBatch.selector), CREDITS_MINTER_ROLE
        );
    }

    function _configureCreditsBurnerRole(
        NFT1155Credits nftCredits,
        NFT1155ExpirableCredits nftExpirableCredits,
        AccessManager accessManager
    ) internal {
        console2.log(
            'Setting Credits Burner Role for burnBatch() and burn() in NFT1155Credits and NFT1155ExpirableCredits'
        );

        accessManager.setTargetFunctionRole(
            address(nftCredits),
            toArray(NFT1155Credits.burnBatch.selector, NFT1155Credits.burn.selector),
            CREDITS_BURNER_ROLE
        );
        accessManager.setTargetFunctionRole(
            address(nftExpirableCredits),
            toArray(NFT1155ExpirableCredits.burnBatch.selector, NFT1155ExpirableCredits.burn.selector),
            CREDITS_BURNER_ROLE
        );
    }
}
