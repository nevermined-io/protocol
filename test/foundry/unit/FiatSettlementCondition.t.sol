// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {AssetsRegistry} from '../../../contracts/AssetsRegistry.sol';
import {NVMConfig} from '../../../contracts/NVMConfig.sol';
import {AgreementsStore} from '../../../contracts/agreements/AgreementsStore.sol';

import {CONTRACT_CONDITION_ROLE, FIAT_SETTLEMENT_ROLE} from '../../../contracts/common/Roles.sol';
import {IAgreement} from '../../../contracts/interfaces/IAgreement.sol';
import {IFiatSettlement} from '../../../contracts/interfaces/IFiatSettlement.sol';
import {INVMConfig} from '../../../contracts/interfaces/INVMConfig.sol';
import {BaseTest} from '../common/BaseTest.sol';

import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {IAccessManaged} from '@openzeppelin/contracts/access/manager/IAccessManaged.sol';

contract FiatSettlementConditionTest is BaseTest {
    address public receiver;

    function setUp() public override {
        super.setUp();
    }

    function test_fulfill_noTemplateRevert() public {
        vm.expectPartialRevert(IAccessManaged.AccessManagedUnauthorized.selector);

        fiatSettlementCondition.fulfill(bytes32(0), bytes32(0), 1, address(this), new bytes[](0));
    }

    function test_fulfill_noAgreementRevert() public {
        _grantTemplateRole(address(this));

        vm.expectPartialRevert(IAgreement.AgreementNotFound.selector);
        fiatSettlementCondition.fulfill(bytes32(0), bytes32(0), 1, address(this), new bytes[](0));
    }

    function test_fulfill_noSettlementRoleRevert() public {
        _grantTemplateRole(address(this));

        bytes32 agreementId = _createAgreement(address(this), 1);
        vm.expectPartialRevert(IFiatSettlement.InvalidRole.selector);
        fiatSettlementCondition.fulfill(bytes32(0), agreementId, 1, address(this), new bytes[](0));
    }

    function test_fulfill_invalidPriceTypeRevert() public {
        _grantTemplateRole(address(this));
        _grantRole(FIAT_SETTLEMENT_ROLE, address(this));

        bytes32 agreementId = _createAgreement(address(this), 1);
        vm.expectPartialRevert(IFiatSettlement.OnlyPlanWithFiatPrice.selector);
        fiatSettlementCondition.fulfill(bytes32(0), agreementId, 1, address(this), new bytes[](0));
    }

    function test_fulfill_okay() public {
        address caller = address(1);
        _grantTemplateRole(address(this));
        _grantRole(FIAT_SETTLEMENT_ROLE, caller);
        _grantConditionRole(address(fiatSettlementCondition));

        uint256 planId = _createPlan();

        bytes32 agreementId = _createAgreement(caller, planId);

        fiatSettlementCondition.fulfill(keccak256('abc'), agreementId, planId, caller, new bytes[](0));
    }
}
