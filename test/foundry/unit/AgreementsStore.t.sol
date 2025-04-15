// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {AgreementsStore} from '../../../contracts/agreements/AgreementsStore.sol';
import {IAgreement} from '../../../contracts/interfaces/IAgreement.sol';
import {INVMConfig} from '../../../contracts/interfaces/INVMConfig.sol';

import {AgreementsStoreV2} from '../../../contracts/mock/AgreementsStoreV2.sol';
import {BaseTest} from '../common/BaseTest.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

contract AgreementsStoreTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_hashAgreement() public view {
        bytes32 agreementId = agreementsStore.hashAgreementId(bytes32(0), address(this));
        assertFalse(agreementId == bytes32(0));
    }

    function test_getNonExistentAgreement() public view {
        bytes32 agreementId = bytes32(uint256(1));
        IAgreement.Agreement memory agreement = agreementsStore.getAgreement(agreementId);
        assertEq(agreement.agreementCreator, address(0));
        assertEq(agreement.lastUpdated, 0);
    }

    function test_onlyTemplatesCanRegisterAgreements() public {
        bytes32 agreementId = bytes32(uint256(1));
        
        // Should revert if not called by a template
        vm.expectPartialRevert(INVMConfig.OnlyTemplate.selector);
        bytes32[] memory conditionIds = new bytes32[](1);
        IAgreement.ConditionState[] memory conditionStates = new IAgreement.ConditionState[](1);
        bytes[] memory params = new bytes[](0);
        conditionIds[0] = bytes32(0);
        conditionStates[0] = IAgreement.ConditionState.Unfulfilled;
        
        agreementsStore.register(agreementId, address(this), bytes32(0), 0, conditionIds, conditionStates, params);
    }

    function test_registerAgreementSuccessfully() public {
        // Grant template role to this contract
        _grantTemplateRole(address(this));
        
        // Create test agreement
        bytes32 agreementId = agreementsStore.hashAgreementId(bytes32(0), address(this));
        bytes32[] memory conditionIds = new bytes32[](1);
        IAgreement.ConditionState[] memory conditionStates = new IAgreement.ConditionState[](1);
        bytes[] memory params = new bytes[](0);
        conditionIds[0] = bytes32(0);
        conditionStates[0] = IAgreement.ConditionState.Unfulfilled;
        
        agreementsStore.register(agreementId, address(this), bytes32(0), 0, conditionIds, conditionStates, params);
        
        // Verify agreement was registered
        IAgreement.Agreement memory agreement = agreementsStore.getAgreement(agreementId);
        assertEq(agreement.agreementCreator, address(this));
        assertTrue(agreement.lastUpdated > 0);
    }

    function test_emitsEventOnAgreementRegistration() public {
        // Grant template role to this contract
        _grantTemplateRole(address(this));
        
        // Create test agreement
        bytes32 agreementId = agreementsStore.hashAgreementId(bytes32(0), address(this));
        
        // Expect AgreementCreated event
        vm.expectEmit(true, true, true, true);
        emit IAgreement.AgreementRegistered(agreementId, address(this));
        
        // Register agreement
        bytes32[] memory conditionIds = new bytes32[](1);
        IAgreement.ConditionState[] memory conditionStates = new IAgreement.ConditionState[](1);
        bytes[] memory params = new bytes[](0);
        conditionIds[0] = bytes32(0);
        conditionStates[0] = IAgreement.ConditionState.Unfulfilled;
        
        agreementsStore.register(agreementId, address(this), bytes32(0), 0, conditionIds, conditionStates, params);
    }

    function test_upgraderShouldBeAbleToUpgradeAfterDelay() public {
        string memory newVersion = '2.0.0';

        uint48 upgradeTime = uint48(block.timestamp + UPGRADE_DELAY);

        AgreementsStoreV2 agreementsStoreV2Impl = new AgreementsStoreV2();

        vm.prank(upgrader);
        accessManager.schedule(
            address(agreementsStore),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(agreementsStoreV2Impl), bytes(''))),
            upgradeTime
        );

        vm.warp(upgradeTime);

        vm.prank(upgrader);
        accessManager.execute(
            address(agreementsStore),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(agreementsStoreV2Impl), bytes('')))
        );

        AgreementsStoreV2 agreementsStoreV2 = AgreementsStoreV2(address(agreementsStore));

        vm.prank(governor);
        agreementsStoreV2.initializeV2(newVersion);

        assertEq(agreementsStoreV2.getVersion(), newVersion);
    }
}
