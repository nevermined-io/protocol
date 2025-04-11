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
import {NFT1155ExpirableCredits} from '../../contracts/token/NFT1155ExpirableCredits.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {Script, console2} from 'forge-std/Script.sol';

/**
 * @title TransferOwnership
 * @notice Foundry script to transfer ownership of all OwnableUpgradeable contracts
 * @dev Run with: forge script scripts/ops/TransferOwnership.s.sol --rpc-url $RPC_URL --broadcast --mnemonics "$OWNER_MNEMONIC" --mnemonic-indexes $OWNER_INDEX --sender $OWNER_ADDRESS
 */
contract TransferOwnership is Script {
    // New owner address
    address public newOwner;
    string public json;

    function setUp() public {
        console2.log('Transferring ownership from address :', msg.sender);

        string memory addressesJson = vm.envOr('DEPLOYMENT_ADDRESSES_JSON', string('./deployments/latest.json'));
        json = vm.readFile(addressesJson);

        console2.log('Configuring contracts with JSON addresses from file: ', addressesJson);
        console2.log(json);

        // Load new owner address
        newOwner = vm.envAddress('NEW_OWNER_ADDRESS');

        // Ensure new owner address is set
        require(newOwner != address(0), 'New owner address not set');
    }

    function run() public {
        // Start broadcasting transactions
        vm.startBroadcast();

        // Transfer ownership of each contract
        transferOwnership(vm.parseJsonAddress(json, '$.contracts.NVMConfig'), 'NVMConfig');
        transferOwnership(vm.parseJsonAddress(json, '$.contracts.AssetsRegistry'), 'AssetsRegistry');
        transferOwnership(vm.parseJsonAddress(json, '$.contracts.PaymentsVault'), 'PaymentsVault');
        transferOwnership(vm.parseJsonAddress(json, '$.contracts.NFT1155Credits'), 'NFT1155Credits');
        transferOwnership(vm.parseJsonAddress(json, '$.contracts.NFT1155ExpirableCredits'), 'NFT1155ExpirableCredits');
        transferOwnership(vm.parseJsonAddress(json, '$.contracts.AgreementsStore'), 'AgreementsStore');
        transferOwnership(vm.parseJsonAddress(json, '$.contracts.FixedPaymentTemplate'), 'FixedPaymentTemplate');
        transferOwnership(vm.parseJsonAddress(json, '$.contracts.LockPaymentCondition'), 'LockPaymentCondition');
        transferOwnership(vm.parseJsonAddress(json, '$.contracts.TransferCreditsCondition'), 'TransferCreditsCondition');
        transferOwnership(
            vm.parseJsonAddress(json, '$.contracts.DistributePaymentsCondition'), 'DistributePaymentsCondition'
        );

        // Stop broadcasting transactions
        vm.stopBroadcast();

        console2.log('Ownership transfer complete');
    }

    function transferOwnership(address contractAddress, string memory contractName) internal {
        console2.log('Transferring ownership of %s:%s to address %s', contractName, contractAddress, newOwner);
        // Skip if contract address is not set
        if (contractAddress == address(0)) {
            console2.log('Skipping %s: address not set', contractName);
            return;
        }

        try OwnableUpgradeable(contractAddress).owner() returns (address currentOwner) {
            console2.log('Current owner of %s: %s', contractName, currentOwner);

            // Transfer ownership
            OwnableUpgradeable(contractAddress).transferOwnership(newOwner);
            console2.log('Ownership of %s transferred to %s', contractName, newOwner);
        } catch {
            console2.log('Failed to transfer ownership of %s', contractName);
        }
    }
}
