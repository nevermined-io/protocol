// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {LockPaymentCondition} from '../../../contracts/conditions/LockPaymentCondition.sol';
import {IAgreement} from '../../../contracts/interfaces/IAgreement.sol';
import {IAsset} from '../../../contracts/interfaces/IAsset.sol';
import {INVMConfig} from '../../../contracts/interfaces/INVMConfig.sol';

import {MockERC20} from '../../../contracts/test/MockERC20.sol';
import {TokenUtils} from '../../../contracts/utils/TokenUtils.sol';
import {BaseTest} from '../common/BaseTest.sol';

contract LockPaymentConditionTest is BaseTest {
    address public receiver;
    address public template;
    address public user;
    MockERC20 public mockERC20;

    bytes32 public conditionId;
    bytes32 public agreementId;
    bytes32 public did;
    uint256 public planId;

    function setUp() public override {
        super.setUp();

        // Setup addresses
        receiver = makeAddr('receiver');
        template = makeAddr('template');
        user = makeAddr('user');

        // Deploy MockERC20
        mockERC20 = new MockERC20('Test Token', 'TST');

        // Grant template role
        vm.startPrank(governor);
        nvmConfig.grantTemplate(template);
        vm.stopPrank();

        // Create a plan with native token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;
        address[] memory receivers = new address[](1);
        receivers[0] = receiver;

        (uint256[] memory finalAmounts, address[] memory finalReceivers) =
            assetsRegistry.addFeesToPaymentsDistribution(amounts, receivers);

        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(0),
            amounts: finalAmounts,
            receivers: finalReceivers,
            contractAddress: address(0)
        });

        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_OWNER,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 100
        });

        // Register asset and plan
        bytes32 didSeed = bytes32(uint256(1));
        did = assetsRegistry.hashDID(didSeed, address(this));

        vm.prank(address(this));
        assetsRegistry.registerAssetAndPlan(didSeed, 'https://nevermined.io', priceConfig, creditsConfig, address(0));

        // Get the plan ID
        planId = assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(0), address(this));

        // Create agreement
        bytes32 agreementSeed = bytes32(uint256(2));
        agreementId = agreementsStore.hashAgreementId(agreementSeed, user);

        // Hash condition ID
        bytes32 contractName = lockPaymentCondition.NVM_CONTRACT_NAME();
        conditionId = lockPaymentCondition.hashConditionId(agreementId, contractName);

        // Register agreement with the condition
        bytes32[] memory conditionIds = new bytes32[](1);
        conditionIds[0] = conditionId;

        IAgreement.ConditionState[] memory conditionStates = new IAgreement.ConditionState[](1);
        conditionStates[0] = IAgreement.ConditionState.Unfulfilled;

        vm.prank(template);
        agreementsStore.register(agreementId, user, did, planId, conditionIds, conditionStates, new bytes[](0));
    }

    function test_deployment() public view {
        // Verify initialization by checking contract name
        bytes32 contractName = lockPaymentCondition.NVM_CONTRACT_NAME();
        assertEq(contractName, keccak256('LockPaymentCondition'));
    }

    function test_fulfill_nativeToken() public {
        // Get plan to determine payment amount
        IAsset.Plan memory plan = assetsRegistry.getPlan(planId);
        uint256 totalAmount = calculateTotalAmount(plan.price.amounts);

        // Fund template with ETH
        vm.deal(template, totalAmount);

        // Fulfill condition with native token
        vm.prank(template);
        lockPaymentCondition.fulfill{value: totalAmount}(conditionId, agreementId, planId, user);

        // Verify condition state
        IAgreement.ConditionState conditionState = agreementsStore.getConditionState(agreementId, conditionId);
        assertEq(uint8(conditionState), uint8(IAgreement.ConditionState.Fulfilled));

        // Verify vault balance
        uint256 vaultBalance = paymentsVault.getBalanceNativeToken();
        assertEq(vaultBalance, totalAmount);
    }

    function test_fulfill_ERC20Token() public {
        // Setup a new plan with ERC20 token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;
        address[] memory receivers = new address[](1);
        receivers[0] = receiver;

        (uint256[] memory finalAmounts, address[] memory finalReceivers) =
            assetsRegistry.addFeesToPaymentsDistribution(amounts, receivers);

        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(mockERC20),
            amounts: finalAmounts,
            receivers: finalReceivers,
            contractAddress: address(0)
        });

        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_OWNER,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 100
        });

        // Register new asset and plan
        bytes32 didSeed = bytes32(uint256(3));
        bytes32 erc20Did = assetsRegistry.hashDID(didSeed, address(this));

        vm.prank(address(this));
        assetsRegistry.registerAssetAndPlan(didSeed, 'https://nevermined.io', priceConfig, creditsConfig, address(0));

        // Get the plan ID
        uint256 erc20PlanId = uint256(assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(0), address(this)));

        // Create agreement
        bytes32 agreementSeed = bytes32(uint256(4));
        bytes32 erc20AgreementId = agreementsStore.hashAgreementId(agreementSeed, user);

        // Hash condition ID
        bytes32 contractName = lockPaymentCondition.NVM_CONTRACT_NAME();
        bytes32 erc20ConditionId = lockPaymentCondition.hashConditionId(erc20AgreementId, contractName);

        // Register agreement with the condition
        bytes32[] memory conditionIds = new bytes32[](1);
        conditionIds[0] = erc20ConditionId;

        IAgreement.ConditionState[] memory conditionStates = new IAgreement.ConditionState[](1);
        conditionStates[0] = IAgreement.ConditionState.Unfulfilled;

        vm.prank(template);
        agreementsStore.register(
            erc20AgreementId, user, erc20Did, erc20PlanId, conditionIds, conditionStates, new bytes[](0)
        );

        // Get plan to determine payment amount
        IAsset.Plan memory plan = assetsRegistry.getPlan(erc20PlanId);
        uint256 totalAmount = calculateTotalAmount(plan.price.amounts);

        // Mint tokens for user and approve for lock payment condition
        mockERC20.mint(user, totalAmount);

        vm.prank(user);
        mockERC20.approve(address(lockPaymentCondition), totalAmount);

        // Fulfill condition with ERC20 token
        vm.prank(template);
        lockPaymentCondition.fulfill(erc20ConditionId, erc20AgreementId, erc20PlanId, user);

        // Verify condition state
        IAgreement.ConditionState conditionState = agreementsStore.getConditionState(erc20AgreementId, erc20ConditionId);
        assertEq(uint8(conditionState), uint8(IAgreement.ConditionState.Fulfilled));

        // Verify vault balance
        uint256 vaultBalance = paymentsVault.getBalanceERC20(address(mockERC20));
        assertEq(vaultBalance, totalAmount);
    }

    function test_revert_notTemplate() public {
        // Try to fulfill condition from non-template account
        // bytes memory revertData = abi.encodeWithSelector(INVMConfig.OnlyTemplate.selector, user);

        vm.expectPartialRevert(INVMConfig.OnlyTemplate.selector);

        lockPaymentCondition.fulfill{value: 100}(conditionId, agreementId, planId, user);
    }

    function test_revert_incorrectPaymentAmount() public {
        // Get plan to determine payment amount
        IAsset.Plan memory plan = assetsRegistry.getPlan(planId);
        uint256 totalAmount = calculateTotalAmount(plan.price.amounts);

        // Fund template with ETH
        vm.deal(template, totalAmount);

        // Try to fulfill condition with incorrect payment amount
        vm.expectRevert(
            abi.encodeWithSelector(TokenUtils.InvalidTransactionAmount.selector, totalAmount - 1, totalAmount)
        );

        vm.prank(template);
        lockPaymentCondition.fulfill{value: totalAmount - 1}(conditionId, agreementId, planId, user);
    }

    function test_revert_unsupportedPriceType() public {
        // Create price config with FIXED_FIAT_PRICE
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100;
        address[] memory receivers = new address[](1);
        receivers[0] = receiver;

        (uint256[] memory finalAmounts, address[] memory finalReceivers) =
            assetsRegistry.addFeesToPaymentsDistribution(amounts, receivers);

        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_FIAT_PRICE, // Unsupported price type
            tokenAddress: address(0),
            amounts: finalAmounts,
            receivers: finalReceivers,
            contractAddress: address(0)
        });

        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_OWNER,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 100
        });

        // Register new asset and plan
        bytes32 didSeed = bytes32(uint256(5));
        bytes32 fiatDid = assetsRegistry.hashDID(didSeed, address(this));

        vm.prank(address(this));
        assetsRegistry.registerAssetAndPlan(didSeed, 'https://nevermined.io', priceConfig, creditsConfig, address(0));

        // Get the plan ID
        uint256 fiatPlanId = uint256(assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(0), address(this)));

        // Create agreement
        bytes32 agreementSeed = bytes32(uint256(6));
        bytes32 fiatAgreementId = agreementsStore.hashAgreementId(agreementSeed, user);

        // Hash condition ID
        bytes32 contractName = lockPaymentCondition.NVM_CONTRACT_NAME();
        bytes32 fiatConditionId = lockPaymentCondition.hashConditionId(fiatAgreementId, contractName);

        // Register agreement with the condition
        bytes32[] memory conditionIds = new bytes32[](1);
        conditionIds[0] = fiatConditionId;

        IAgreement.ConditionState[] memory conditionStates = new IAgreement.ConditionState[](1);
        conditionStates[0] = IAgreement.ConditionState.Unfulfilled;

        vm.prank(template);
        agreementsStore.register(
            fiatAgreementId, user, fiatDid, fiatPlanId, conditionIds, conditionStates, new bytes[](0)
        );

        // Try to fulfill condition with FIXED_FIAT_PRICE
        vm.expectRevert(
            abi.encodeWithSelector(
                LockPaymentCondition.UnsupportedPriceTypeOption.selector, IAsset.PriceType.FIXED_FIAT_PRICE
            )
        );

        vm.prank(template);
        lockPaymentCondition.fulfill(fiatConditionId, fiatAgreementId, fiatPlanId, user);
    }

    // Helper function to calculate the total amount from an array of amounts
    function calculateTotalAmount(uint256[] memory amounts) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        return total;
    }
}
