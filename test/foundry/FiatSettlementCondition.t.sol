// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {NVMConfig} from "../../contracts/NVMConfig.sol";
import {INVMConfig} from "../../contracts/interfaces/INVMConfig.sol";
import {AssetsRegistry} from "../../contracts/AssetsRegistry.sol";
import {IAsset} from "../../contracts/interfaces/IAsset.sol";
import {AgreementsStore} from "../../contracts/agreements/AgreementsStore.sol";
import {IAgreement} from "../../contracts/interfaces/IAgreement.sol";
import {FiatSettlementCondition} from "../../contracts/conditions/FiatSettlementCondition.sol";

contract FiatSettlementConditionTest is Test {
    NVMConfig public nvmConfig;
    AssetsRegistry public assetsRegistry;
    AgreementsStore public agreementsStore;
    FiatSettlementCondition public fiatSettlementCondition;

    address public owner;
    address public receiver;

    function setUp() public {
        nvmConfig = new NVMConfig();
        owner = address(this);
        receiver = address(1);
        nvmConfig.initialize(owner, owner);
        nvmConfig.setNetworkFees(100, owner);

        assetsRegistry = new AssetsRegistry();
        assetsRegistry.initialize(address(nvmConfig));

        agreementsStore = new AgreementsStore();
        agreementsStore.initialize(address(nvmConfig));

        agreementsStore = new AgreementsStore();
        agreementsStore.initialize(address(nvmConfig));

        fiatSettlementCondition = new FiatSettlementCondition();
        fiatSettlementCondition.initialize(
            address(nvmConfig),
            address(assetsRegistry),
            address(agreementsStore)
        );
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
        nvmConfig.grantRole(nvmConfig.CONTRACT_TEMPLATE_ROLE(), address(this));

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
        nvmConfig.grantRole(nvmConfig.CONTRACT_TEMPLATE_ROLE(), address(this));

        bytes32 agreementId = _createAgreement();
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
        nvmConfig.grantRole(nvmConfig.CONTRACT_TEMPLATE_ROLE(), address(this));
        nvmConfig.grantRole(fiatSettlementCondition.FIAT_SETTLEMENT_ROLE(), address(this));

        bytes32 agreementId = _createAgreement();
        vm.expectPartialRevert(FiatSettlementCondition.OnlyPlanWithFiatPrice.selector);
        fiatSettlementCondition.fulfill(
            bytes32(0),
            agreementId,
            1,
            address(this),
            new bytes[](0)
        );
    }

    function test_fulfill_invalidConditionIdRevert() public {
        address caller = address(1);
        nvmConfig.grantRole(nvmConfig.CONTRACT_TEMPLATE_ROLE(), caller);
        nvmConfig.grantRole(fiatSettlementCondition.FIAT_SETTLEMENT_ROLE(), caller);
        nvmConfig.grantRole(nvmConfig.CONTRACT_CONDITION_ROLE(), address(fiatSettlementCondition));

        uint256 planId = _createPlan();

        vm.prank(caller);
        bytes32 agreementId = _createAgreement();

        vm.expectPartialRevert(IAgreement.ConditionIdNotFound.selector);
        vm.prank(caller);
        fiatSettlementCondition.fulfill(
            bytes32(0),
            agreementId,
            planId,
            caller,
            new bytes[](0)
        );
    }

    function test_fulfill_okay() public {
        address caller = address(1);
        nvmConfig.grantRole(nvmConfig.CONTRACT_TEMPLATE_ROLE(), caller);
        nvmConfig.grantRole(fiatSettlementCondition.FIAT_SETTLEMENT_ROLE(), caller);
        nvmConfig.grantRole(nvmConfig.CONTRACT_CONDITION_ROLE(), address(fiatSettlementCondition));

        uint256 planId = _createPlan();

        vm.prank(caller);
        bytes32 agreementId = _createAgreement();

        vm.expectPartialRevert(IAgreement.ConditionIdNotFound.selector);
        vm.prank(caller);
        fiatSettlementCondition.fulfill(
            bytes32(0),
            agreementId,
            planId,
            caller,
            new bytes[](0)
        );
    }

    function _createAgreement() internal returns (bytes32) {

        bytes32[] memory conditionIds = new bytes32[](1);
        IAgreement.ConditionState[] memory conditionStates = new IAgreement.ConditionState[](1);
        
        conditionIds[0] = keccak256("abc");
        conditionStates[0] = IAgreement.ConditionState.Unfulfilled;

        bytes32 agreementId = keccak256("123");
        agreementsStore.register(
            agreementId,
            address(this),
            bytes32(0),
            1,
            conditionIds,
            conditionStates,
            new bytes[](0)
        );
        return agreementId;
    }

    function _createPlan() internal returns (uint256) {
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 100;
        address[] memory _receivers = new address[](1);
        _receivers[0] = owner;

        (uint256[] memory amounts, address[] memory receivers) =
            assetsRegistry.addFeesToPaymentsDistribution(_amounts, _receivers);
        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_FIAT_PRICE,
            tokenAddress: address(0),
            amounts: amounts,
            receivers: receivers,
            contractAddress: address(0)
        });
        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 1
        });

        assetsRegistry.createPlan(priceConfig, creditsConfig, address(0));
        return assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(0), address(this));
    }

}
