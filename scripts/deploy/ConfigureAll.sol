// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import {DeployConfig} from './DeployConfig.sol';
import {ManagePermissions} from './ManagePermissions.sol';

import {AssetsRegistry} from '../../contracts/AssetsRegistry.sol';
import {NVMConfig} from '../../contracts/NVMConfig.sol';
import {AgreementsStore} from '../../contracts/agreements/AgreementsStore.sol';

import {PaymentsVault} from '../../contracts/PaymentsVault.sol';

import {DistributePaymentsCondition} from '../../contracts/conditions/DistributePaymentsCondition.sol';

import {FiatSettlementCondition} from '../../contracts/conditions/FiatSettlementCondition.sol';
import {LockPaymentCondition} from '../../contracts/conditions/LockPaymentCondition.sol';
import {TransferCreditsCondition} from '../../contracts/conditions/TransferCreditsCondition.sol';

import {FiatPaymentTemplate} from '../../contracts/agreements/FiatPaymentTemplate.sol';
import {FixedPaymentTemplate} from '../../contracts/agreements/FixedPaymentTemplate.sol';
import {ProtocolStandardFees} from '../../contracts/fees/ProtocolStandardFees.sol';
import {OneTimeCreatorHook} from '../../contracts/hooks/OneTimeCreatorHook.sol';
import {NFT1155Credits} from '../../contracts/token/NFT1155Credits.sol';
import {NFT1155ExpirableCredits} from '../../contracts/token/NFT1155ExpirableCredits.sol';

import {AccessManager} from '@openzeppelin/contracts/access/manager/AccessManager.sol';
import {Script} from 'lib/forge-std/src/Script.sol';
import {console2} from 'lib/forge-std/src/console2.sol';

contract ConfigureAll is Script, DeployConfig {
    function run() public {
        string memory addressesJson = vm.envOr('DEPLOYMENT_ADDRESSES_JSON', string('./deployments/latest.json'));
        string memory json = vm.readFile(addressesJson);
        if (debug) console2.log(json);

        address ownerAddress = vm.parseJsonAddress(json, '$.owner');
        address governorAddress = vm.parseJsonAddress(json, '$.governor');

        if (debug) console2.log('Configuring contracts with Owner address:', ownerAddress);
        console2.log('Configuring contracts with JSON addresses from file:', addressesJson);

        // Load the deployment scripts
        ManagePermissions managePermissions = new ManagePermissions();

        ManagePermissions.Config memory config = ManagePermissions.Config({
            owner: ownerAddress,
            governor: governorAddress,
            upgrader: ownerAddress,
            nvmConfig: NVMConfig(vm.parseJsonAddress(json, '$.contracts.NVMConfig')),
            assetsRegistry: AssetsRegistry(vm.parseJsonAddress(json, '$.contracts.AssetsRegistry')),
            agreementsStore: AgreementsStore(vm.parseJsonAddress(json, '$.contracts.AgreementsStore')),
            paymentsVault: PaymentsVault(payable(vm.parseJsonAddress(json, '$.contracts.PaymentsVault'))),
            nftCredits: NFT1155Credits(vm.parseJsonAddress(json, '$.contracts.NFT1155Credits')),
            nftExpirableCredits: NFT1155ExpirableCredits(vm.parseJsonAddress(json, '$.contracts.NFT1155ExpirableCredits')),
            lockPaymentCondition: LockPaymentCondition(vm.parseJsonAddress(json, '$.contracts.LockPaymentCondition')),
            distributePaymentsCondition: DistributePaymentsCondition(
                vm.parseJsonAddress(json, '$.contracts.DistributePaymentsCondition')
            ),
            transferCreditsCondition: TransferCreditsCondition(
                vm.parseJsonAddress(json, '$.contracts.TransferCreditsCondition')
            ),
            fiatSettlementCondition: FiatSettlementCondition(
                vm.parseJsonAddress(json, '$.contracts.FiatSettlementCondition')
            ),
            fixedPaymentTemplate: FixedPaymentTemplate(vm.parseJsonAddress(json, '$.contracts.FixedPaymentTemplate')),
            fiatPaymentTemplate: FiatPaymentTemplate(vm.parseJsonAddress(json, '$.contracts.FiatPaymentTemplate')),
            accessManager: AccessManager(vm.parseJsonAddress(json, '$.contracts.AccessManager')),
            oneTimeCreatorHook: OneTimeCreatorHook(vm.parseJsonAddress(json, '$.contracts.OneTimeCreatorHook')),
            protocolStandardFees: ProtocolStandardFees(vm.parseJsonAddress(json, '$.contracts.ProtocolStandardFees'))
        });

        managePermissions.run(config);
        if (debug) console2.log('Permissions configured');

        string memory blockNumberJson = vm.toString(block.number);
        vm.writeJson(blockNumberJson, addressesJson, '$.blockNumber');
        if (debug) console2.log('Added block number to JSON:', block.number);

        uint256 snapshotId = vm.snapshotState();
        string memory snapshotIdString = vm.toString(snapshotId);
        vm.writeJson(snapshotIdString, addressesJson, '$.snapshotId');
        if (debug) console2.log('Added snapshot id to JSON:', snapshotId);
    }
}
