// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

import {FiatPaymentTemplate} from '../../../contracts/agreements/FiatPaymentTemplate.sol';
import {FixedPaymentTemplate} from '../../../contracts/agreements/FixedPaymentTemplate.sol';

import {FIAT_SETTLEMENT_ROLE} from '../../../contracts/common/Roles.sol';
import {OneTimeCreatorHook} from '../../../contracts/hooks/OneTimeCreatorHook.sol';
import {IFeeController} from '../../../contracts/interfaces/IFeeController.sol';

import {IAgreement} from '../../../contracts/interfaces/IAgreement.sol';
import {IAsset} from '../../../contracts/interfaces/IAsset.sol';
import {IHook} from '../../../contracts/interfaces/IHook.sol';
import {BaseTest} from '../common/BaseTest.sol';

contract OneTimeCreatorHookTest is BaseTest {
    address creator;
    address buyer;
    uint256 planId;

    function setUp() public override {
        super.setUp();
        creator = makeAddr('creator');
        vm.label(creator, 'creator');
        buyer = makeAddr('buyer');
        vm.label(buyer, 'buyer');

        // Grant template role to this contract
        _grantTemplateRole(address(this));
        _grantTemplateRole(buyer);
        _grantRole(FIAT_SETTLEMENT_ROLE, buyer);

        // Create a plan with the OneTimeCreatorHook
        IHook[] memory hooks = new IHook[](1);
        hooks[0] = oneTimeCreatorHook;
        planId = _createPlanWithHooks(hooks);
    }

    function test_WorksWithFiatPaymentTemplate() public {
        // Create agreement using FiatPaymentTemplate
        bytes32 seed = keccak256('test-seed');
        bytes[] memory params = new bytes[](0);

        // Calculate expected agreement ID
        bytes32 expectedAgreementId =
            keccak256(abi.encode(fiatPaymentTemplate.NVM_CONTRACT_NAME(), buyer, seed, planId, buyer, params));

        // Create first agreement
        vm.prank(buyer);
        vm.expectEmit(true, true, true, true);
        emit IAgreement.AgreementRegistered(expectedAgreementId, buyer);
        fiatPaymentTemplate.createAgreement(seed, planId, buyer, params);

        // Second attempt should fail
        vm.prank(buyer);
        vm.expectPartialRevert(OneTimeCreatorHook.CreatorAlreadyCreatedAgreement.selector);
        fiatPaymentTemplate.createAgreement(keccak256('test-seed-2'), planId, buyer, params);
    }

    function _createPlanWithHooks(IHook[] memory hooks) internal returns (uint256) {
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 100;
        address[] memory _receivers = new address[](1);
        _receivers[0] = creator;

        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_FIAT_PRICE,
            tokenAddress: address(0),
            amounts: new uint256[](0),
            receivers: new address[](0),
            contractAddress: address(0)
        });
        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.FIXED,
            redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
            durationSecs: 0,
            amount: 100,
            minAmount: 1,
            maxAmount: 1,
            proofRequired: false
        });

        (uint256[] memory amounts, address[] memory receivers) = assetsRegistry.addFeesToPaymentsDistribution(
            _amounts, _receivers, priceConfig, creditsConfig, address(0), IFeeController(address(0))
        );
        priceConfig.amounts = amounts;
        priceConfig.receivers = receivers;

        address nftAddress = address(nftCredits);
        vm.prank(creator);
        assetsRegistry.createPlanWithHooks(priceConfig, creditsConfig, nftAddress, hooks, IFeeController(address(0)));
        return assetsRegistry.hashPlanId(priceConfig, creditsConfig, nftAddress, creator, 0);
    }
}
