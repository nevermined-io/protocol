// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {FiatPaymentTemplate} from '../../../contracts/agreements/FiatPaymentTemplate.sol';
import {IAgreement} from '../../../contracts/interfaces/IAgreement.sol';
import {IAsset} from '../../../contracts/interfaces/IAsset.sol';
import {INVMConfig} from '../../../contracts/interfaces/INVMConfig.sol';
import {ITemplate} from '../../../contracts/interfaces/ITemplate.sol';

import {BaseTest} from '../common/BaseTest.sol';

contract FiatPaymentTemplateTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_createAgreement() public {
        // Grant template role to this contract
        _grantTemplateRole(address(this));

        // Create a plan
        uint256 planId = _createPlan();

        // Create agreement using FiatPaymentTemplate
        bytes32 agreementSeed = bytes32(uint256(2));
        address creditsReceiver = makeAddr('creditsReceiver');
        bytes[] memory params = new bytes[](0);

        // Calculate expected agreement ID
        bytes32 expectedAgreementId = keccak256(
            abi.encode(
                fiatPaymentTemplate.NVM_CONTRACT_NAME(), address(this), agreementSeed, planId, creditsReceiver, params
            )
        );

        // Create agreement
        vm.expectEmit(true, true, true, true);
        emit IAgreement.AgreementRegistered(expectedAgreementId, address(this));
        fiatPaymentTemplate.createAgreement(agreementSeed, planId, creditsReceiver, params);

        // Verify agreement was registered
        IAgreement.Agreement memory agreement = agreementsStore.getAgreement(expectedAgreementId);
        assertEq(agreement.agreementCreator, address(this));
        assertTrue(agreement.lastUpdated > 0);
        assertEq(agreement.planId, planId);
        assertEq(agreement.conditionIds.length, 2);

        // Verify condition states
        IAgreement.ConditionState state1 =
            agreementsStore.getConditionState(expectedAgreementId, agreement.conditionIds[0]);
        IAgreement.ConditionState state2 =
            agreementsStore.getConditionState(expectedAgreementId, agreement.conditionIds[1]);
        assertEq(uint8(state1), uint8(IAgreement.ConditionState.Fulfilled));
        assertEq(uint8(state2), uint8(IAgreement.ConditionState.Fulfilled));

        // Verify NFT credits were minted to the receiver
        assertEq(nftCredits.balanceOf(creditsReceiver, planId), 100, 'Credits should be minted to receiver');
        assertEq(nftCredits.balanceOf(address(this), planId), 0, 'Creator should not have credits');
    }

    function test_createAgreement_revertIfPlanNotFound() public {
        // Grant template role to this contract
        _grantTemplateRole(address(this));

        // Try to create agreement with non-existent plan
        bytes32 agreementSeed = bytes32(uint256(2));
        uint256 nonExistentPlanId = 999;
        address creditsReceiver = makeAddr('creditsReceiver');
        bytes[] memory params = new bytes[](0);

        vm.expectRevert(abi.encodeWithSelector(IAsset.PlanNotFound.selector, nonExistentPlanId));
        fiatPaymentTemplate.createAgreement(agreementSeed, nonExistentPlanId, creditsReceiver, params);
    }

    function test_createAgreement_revertIfZeroAddressReceiver() public {
        // Grant template role to this contract
        _grantTemplateRole(address(this));

        // Create a plan first
        uint256 planId = _createPlan();

        // Try to create agreement with zero address receiver
        bytes32 agreementSeed = bytes32(uint256(2));
        address zeroAddress = address(0);
        bytes[] memory params = new bytes[](0);

        vm.expectRevert(abi.encodeWithSelector(ITemplate.InvalidReceiver.selector, zeroAddress));
        fiatPaymentTemplate.createAgreement(agreementSeed, planId, zeroAddress, params);
    }

    function test_createAgreement_revertIfInvalidSeed() public {
        // Grant template role to this contract
        _grantTemplateRole(address(this));

        // Create a plan first
        uint256 planId = _createPlan();

        // Try to create agreement with zero seed
        bytes32 zeroSeed = bytes32(0);
        address creditsReceiver = makeAddr('creditsReceiver');
        bytes[] memory params = new bytes[](0);

        vm.expectRevert(abi.encodeWithSelector(ITemplate.InvalidSeed.selector, zeroSeed));
        fiatPaymentTemplate.createAgreement(zeroSeed, planId, creditsReceiver, params);
    }

    function test_createAgreement_revertIfInvalidPlanID() public {
        // Grant template role to this contract
        _grantTemplateRole(address(this));

        // Try to create agreement with zero plan ID
        bytes32 agreementSeed = bytes32(uint256(2));
        uint256 zeroPlanId = 0;
        address creditsReceiver = makeAddr('creditsReceiver');
        bytes[] memory params = new bytes[](0);

        vm.expectRevert(abi.encodeWithSelector(ITemplate.InvalidPlanId.selector, zeroPlanId));
        fiatPaymentTemplate.createAgreement(agreementSeed, zeroPlanId, creditsReceiver, params);
    }

    function test_createAgreement_revertIfAgreementAlreadyRegistered() public {
        // Grant template role to this contract
        _grantTemplateRole(address(this));

        // Create a plan
        uint256 planId = _createPlan();

        // Create agreement using FiatPaymentTemplate
        bytes32 agreementSeed = bytes32(uint256(2));
        address creditsReceiver = makeAddr('creditsReceiver');
        bytes[] memory params = new bytes[](0);

        // Calculate expected agreement ID
        bytes32 expectedAgreementId = keccak256(
            abi.encode(
                fiatPaymentTemplate.NVM_CONTRACT_NAME(), address(this), agreementSeed, planId, creditsReceiver, params
            )
        );

        // Create first agreement
        fiatPaymentTemplate.createAgreement(agreementSeed, planId, creditsReceiver, params);

        // Try to create the same agreement again
        vm.expectRevert(abi.encodeWithSelector(IAgreement.AgreementAlreadyRegistered.selector, expectedAgreementId));
        fiatPaymentTemplate.createAgreement(agreementSeed, planId, creditsReceiver, params);
    }
}
