// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {AssetsRegistry} from '../../contracts/AssetsRegistry.sol';
import {NVMConfig} from '../../contracts/NVMConfig.sol';

import {PaymentsVault} from '../../contracts/PaymentsVault.sol';
import {AgreementsStore} from '../../contracts/agreements/AgreementsStore.sol';

import {FixedPaymentTemplate} from '../../contracts/agreements/FixedPaymentTemplate.sol';
import {DistributePaymentsCondition} from '../../contracts/conditions/DistributePaymentsCondition.sol';
import {LockPaymentCondition} from '../../contracts/conditions/LockPaymentCondition.sol';
import {TransferCreditsCondition} from '../../contracts/conditions/TransferCreditsCondition.sol';
import {NFT1155Credits} from '../../contracts/token/NFT1155Credits.sol';
import {TokenUtils} from '../../contracts/utils/TokenUtils.sol';
import {Constants} from '../Constants.sol';
import {DeployConditions} from './DeployConditions.sol';
import {DeployConfig} from './DeployConfig.sol';
import {DeployCoreContracts} from './DeployCoreContracts.sol';
import {DeployLibraries} from './DeployLibraries.sol';
import {DeployNFTContracts} from './DeployNFTContracts.sol';
import {DeployNVMConfig} from './DeployNVMConfig.sol';

import {DeployTemplates} from './DeployTemplates.sol';
import {ManagePermissions} from './ManagePermissions.sol';

import {SetNetworkFees} from './SetNetworkFees.sol';
import {AccessManager} from '@openzeppelin/contracts/access/manager/AccessManager.sol';
import {Script} from 'forge-std/Script.sol';
import {console} from 'forge-std/console.sol';

contract ConfigureAll is Script, DeployConfig {
    function run() public {
        address governorAddress = msg.sender;

        console.log('Configuring contracts with Governor address:', governorAddress);

        string memory addressesJson = vm.envOr('DEPLOYMENT_ADDRESSES_JSON', string('./deployments/latest.json'));

        string memory json = vm.readFile(addressesJson);

        console.log('Configuring contracts with JSON addresses from file:', addressesJson);
        console.log(json);

        // Load the deployment scripts
        ManagePermissions managePermissions = new ManagePermissions();
        SetNetworkFees setNetworkFees = new SetNetworkFees();

        managePermissions.run(
            governorAddress,
            vm.parseJsonAddress(json, '$.contracts.NVMConfig'),
            vm.parseJsonAddress(json, '$.contracts.PaymentsVault'),
            vm.parseJsonAddress(json, '$.contracts.NFT1155Credits'),
            vm.parseJsonAddress(json, '$.contracts.LockPaymentCondition'),
            vm.parseJsonAddress(json, '$.contracts.DistributePaymentsCondition'),
            vm.parseJsonAddress(json, '$.contracts.TransferCreditsCondition'),
            vm.parseJsonAddress(json, '$.contracts.FiatSettlementCondition'),
            vm.parseJsonAddress(json, '$.contracts.FixedPaymentTemplate'),
            vm.parseJsonAddress(json, '$.contracts.FiatPaymentTemplate'),
            vm.parseJsonAddress(json, '$.contracts.AccessManager')
        );
        console.log('Permissions configured');

        setNetworkFees.run(governorAddress, vm.parseJsonAddress(json, '$.contracts.NVMConfig'));
    }
}
