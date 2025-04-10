// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {NVMConfig} from '../../contracts/NVMConfig.sol';
import {PaymentsVault} from '../../contracts/PaymentsVault.sol';
import {INVMConfig} from '../../contracts/interfaces/INVMConfig.sol';
import {NFT1155Credits} from '../../contracts/token/NFT1155Credits.sol';
import {Constants} from '../../scripts/Constants.sol';
import {DeployConfig} from './DeployConfig.sol';

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {AccessManager} from '@openzeppelin/contracts/access/manager/AccessManager.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

contract ManagePermissions is Script, DeployConfig {
    // Define roles
    uint64 constant UPGRADE_ROLE = uint64(uint256(keccak256(abi.encode('UPGRADE_ROLE'))));
    bytes32 constant DEPOSITOR_ROLE = keccak256(abi.encode('DEPOSITOR_ROLE'));
    bytes32 constant WITHDRAW_ROLE = keccak256(abi.encode('WITHDRAW_ROLE'));
    bytes32 constant CREDITS_MINTER_ROLE = keccak256(abi.encode('CREDITS_MINTER_ROLE'));

    function run(
        address governor,
        address nvmConfig,
        address paymentsVault,
        address nftCredits,
        address lockPaymentCondition,
        address distributePaymentsCondition,
        address transferCreditsCondition,
        address fiatSettlementCondition,
        address fixedPaymentTemplate,
        address fiatPaymentTemplate,
        address accessManager
    ) public {
        console.log('Managing permissions for contracts...');

        vm.startBroadcast(governor);

        // Get AccessManager instance
        AccessManager accessManagerInstance = AccessManager(accessManager);

        // Grant condition permissions
        NVMConfig(nvmConfig).grantCondition(lockPaymentCondition);
        NVMConfig(nvmConfig).grantCondition(transferCreditsCondition);
        NVMConfig(nvmConfig).grantCondition(distributePaymentsCondition);
        NVMConfig(nvmConfig).grantCondition(fiatSettlementCondition);

        // Grant template permissions
        NVMConfig(nvmConfig).grantTemplate(fixedPaymentTemplate);
        NVMConfig(nvmConfig).grantTemplate(fiatPaymentTemplate);

        // Grant Deposit and Withdrawal permissions to Payments Vault
        // NVMConfig(nvmConfig).grantRole(DEPOSITOR_ROLE, lockPaymentCondition);
        // NVMConfig(nvmConfig).grantRole(WITHDRAW_ROLE, distributePaymentsCondition);

        // Grant Mint permissions to transferNFTCondition on NFT1155Credits contracts
        // NVMConfig(nvmConfig).grantRole(CREDITS_MINTER_ROLE, transferCreditsCondition);

        // Grant Upgrade permissions to NVMConfig
        // accessManagerInstance.setTargetFunctionRole(
        //   nvmConfig,
        //   toArray(UUPSUpgradeable.upgradeToAndCall.selector),
        //   UPGRADE_ROLE
        // );

        // Grant Upgrade permissions to PaymentsVault
        // accessManagerInstance.setTargetFunctionRole(
        //   paymentsVault,
        //   toArray(UUPSUpgradeable.upgradeToAndCall.selector),
        //   UPGRADE_ROLE
        // );

        // Grant Upgrade permissions to NFT1155Credits
        // accessManagerInstance.setTargetFunctionRole(
        //   nftCredits,
        //   toArray(UUPSUpgradeable.upgradeToAndCall.selector),
        //   UPGRADE_ROLE
        // );

        vm.stopBroadcast();

        console.log('Permissions configured successfully');
    }

    function toArray(bytes4 selector) internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = selector;
        return selectors;
    }
}
