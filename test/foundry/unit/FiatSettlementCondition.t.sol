// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { BaseTest } from '../common/BaseTest.sol';
import {INVMConfig} from "../../../contracts/interfaces/INVMConfig.sol";
import {IFiatSettlement} from "../../../contracts/interfaces/IFiatSettlement.sol";
import {IAgreement} from "../../../contracts/interfaces/IAgreement.sol";

import {NVMConfig} from "../../../contracts/NVMConfig.sol";
import {AssetsRegistry} from "../../../contracts/AssetsRegistry.sol";
import {AgreementsStore} from "../../../contracts/agreements/AgreementsStore.sol";
import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';

contract FiatSettlementConditionTest is BaseTest {
    // NVMConfig public nvmConfig;
    // AssetsRegistry public assetsRegistry;
    // AgreementsStore public agreementsStore;
    // FiatSettlementCondition public fiatSettlementCondition;

    address public receiver;

    function setUp() public override {
        super.setUp();
        // nvmConfig = new NVMConfig();
        // owner = address(this);
        // receiver = address(1);
        // nvmConfig.initialize(owner, owner);
        // nvmConfig.setNetworkFees(100, owner);

        // assetsRegistry = new AssetsRegistry();
        // assetsRegistry.initialize(address(nvmConfig));

        // agreementsStore = new AgreementsStore();
        // agreementsStore.initialize(address(nvmConfig), address(0));

        // agreementsStore = new AgreementsStore();
        // agreementsStore.initialize(address(nvmConfig), address(0));

        // fiatSettlementCondition = new FiatSettlementCondition();
        // fiatSettlementCondition.initialize(
        //     address(nvmConfig),
        //     address(assetsRegistry),
        //     address(agreementsStore)
        // );
    }

    function test_fulfill_noTemplateRevert() public {
        vm.expectPartialRevert(INVMConfig.OnlyTemplate.selector);

        fiatSettlementCondition.fulfill(
            bytes32(0),
            bytes32(0),
            1,
            address(this),
            new bytes[](0)
        );
    }

    function test_fulfill_noAgreementRevert() public {
        _grantTemplateRole(address(this));

        vm.expectPartialRevert(IAgreement.AgreementNotFound.selector);
        fiatSettlementCondition.fulfill(
            bytes32(0),
            bytes32(0),
            1,
            address(this),
            new bytes[](0)
        );
    }

    function test_fulfill_noSettlementRoleRevert() public {
        _grantTemplateRole(address(this));

        bytes32 agreementId = _createAgreement(address(this), 1);
        vm.expectPartialRevert(INVMConfig.InvalidRole.selector);
        fiatSettlementCondition.fulfill(
            bytes32(0),
            agreementId,
            1,
            address(this),
            new bytes[](0)
        );
    }

    function test_fulfill_invalidPriceTypeRevert() public {
        _grantTemplateRole(address(this));
        _grantNVMConfigRole(fiatSettlementCondition.FIAT_SETTLEMENT_ROLE(), address(this));

        bytes32 agreementId = _createAgreement(address(this), 1);
        vm.expectPartialRevert(IFiatSettlement.OnlyPlanWithFiatPrice.selector);
        fiatSettlementCondition.fulfill(
            bytes32(0),
            agreementId,
            1,
            address(this),
            new bytes[](0)
        );
    }

    function test_fulfill_okay() public {
        address caller = address(1);
        _grantTemplateRole(address(this));
        _grantNVMConfigRole(fiatSettlementCondition.FIAT_SETTLEMENT_ROLE(), caller);
        _grantNVMConfigRole(nvmConfig.CONTRACT_CONDITION_ROLE(), address(fiatSettlementCondition));

        uint256 planId = _createPlan();

        vm.startPrank(caller);
        bytes32 agreementId = _createAgreement(caller, planId);

        fiatSettlementCondition.fulfill(
            keccak256("abc"),
            agreementId,
            planId,
            caller,
            new bytes[](0)
        );
        vm.stopPrank();
    }



}
