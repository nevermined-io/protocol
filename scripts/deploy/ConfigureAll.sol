// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Constants} from "../Constants.sol";
import {DeployConfig} from "./DeployConfig.sol";
import {DeployNVMConfig} from "./DeployNVMConfig.sol";
import {DeployLibraries} from "./DeployLibraries.sol";
import {DeployCoreContracts} from "./DeployCoreContracts.sol";
import {DeployNFTContracts} from "./DeployNFTContracts.sol";
import {DeployConditions} from "./DeployConditions.sol";
import {DeployTemplates} from "./DeployTemplates.sol";
import {ManagePermissions} from "./ManagePermissions.sol";
import {NVMConfig} from "../../contracts/NVMConfig.sol";
import {TokenUtils} from "../../contracts/utils/TokenUtils.sol";
import {AssetsRegistry} from "../../contracts/AssetsRegistry.sol";
import {AgreementsStore} from "../../contracts/agreements/AgreementsStore.sol";
import {PaymentsVault} from "../../contracts/PaymentsVault.sol";
import {NFT1155Credits} from "../../contracts/token/NFT1155Credits.sol";
import {LockPaymentCondition} from "../../contracts/conditions/LockPaymentCondition.sol";
import {TransferCreditsCondition} from "../../contracts/conditions/TransferCreditsCondition.sol";
import {DistributePaymentsCondition} from "../../contracts/conditions/DistributePaymentsCondition.sol";
import {FixedPaymentTemplate} from "../../contracts/agreements/FixedPaymentTemplate.sol";
import {SetNetworkFees} from "./SetNetworkFees.sol";

contract ConfigureAll is Script, DeployConfig {
    function run() public {

        address governorAddress = msg.sender;

        console.log("Configuring contracts with Governor address :", governorAddress);                

        string memory addressesJson = vm.envOr('DEPLOYMENT_ADDRESSES_JSON', string('./deployments/latest.json'));

        string memory json = vm.readFile(addressesJson);


        console.log("Configuring contracts with JSON addresses from file: ", addressesJson);
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
            vm.parseJsonAddress(json, '$.contracts.FiatPaymentTemplate')
        );
        console.log("Permissions configured");

        setNetworkFees.run(
            governorAddress,
            vm.parseJsonAddress(json, '$.contracts.NVMConfig')
        );
        
        
    }
}
