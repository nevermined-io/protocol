// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {IAgreement} from '../interfaces/IAgreement.sol';
import {IAsset} from '../interfaces/IAsset.sol';
import {IFiatSettlement} from '../interfaces/IFiatSettlement.sol';
import {INVMConfig} from '../interfaces/INVMConfig.sol';
import {TemplateCondition} from './TemplateCondition.sol';
import {ReentrancyGuardUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';

contract FiatSettlementCondition is ReentrancyGuardUpgradeable, TemplateCondition, IFiatSettlement {
    bytes32 public constant NVM_CONTRACT_NAME = keccak256('FiatSettlementCondition');

    /**
     * @notice Role granted to accounts allowing to settle the fiat payment conditions (they can fulfill the Fiat Settlement conditions)
     * @dev This role is granted to the accounts doing the off-chain fiat settlement validation via the integration with an external provider (i.e Stripe)
     */
    bytes32 public constant FIAT_SETTLEMENT_ROLE = keccak256('FIAT_SETTLEMENT_ROLE');

    // keccak256(abi.encode(uint256(keccak256("nevermined.fiatsettlementcondition.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant FIAT_SETTLEMENT_CONDITION_STORAGE_LOCATION =
        0x095caca12ac306f9c5f97a85684602873cc5f88a30652025e72016cece54ad00;

    /// @custom:storage-location erc7201:nevermined.fiatsettlementcondition.storage
    struct FiatSettlementConditionStorage {
        INVMConfig nvmConfig;
        IAsset assetsRegistry;
        IAgreement agreementStore;
    }

    function initialize(
        INVMConfig _nvmConfigAddress,
        IAccessManager _authority,
        IAsset _assetsRegistryAddress,
        IAgreement _agreementStoreAddress
    ) public initializer {
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        FiatSettlementConditionStorage storage $ = _getFiatSettlementConditionStorage();

        $.nvmConfig = _nvmConfigAddress;
        $.assetsRegistry = _assetsRegistryAddress;
        $.agreementStore = _agreementStoreAddress;
        __AccessManagedUUPSUpgradeable_init(address(_authority));
    }

    function fulfill(
        bytes32 _conditionId,
        bytes32 _agreementId,
        uint256 _planId,
        address _senderAddress,
        bytes[] memory _params
    ) external nonReentrant {
        FiatSettlementConditionStorage storage $ = _getFiatSettlementConditionStorage();

        // Validate if the account calling this function is a registered template
        if (!$.nvmConfig.isTemplate(msg.sender)) revert INVMConfig.OnlyTemplate(msg.sender);

        // Check if the agreementId is registered in the AssetsRegistry
        if (!$.agreementStore.agreementExists(_agreementId)) {
            revert IAgreement.AgreementNotFound(_agreementId);
        }

        // Check if the plan config (token, amount) is correct
        IAsset.Plan memory plan = $.assetsRegistry.getPlan(_planId);

        // Only an account with FIAT_SETTLEMENT_ROLE and not being the owner can fulfill the Fiat Settlement condition
        if (!$.nvmConfig.hasRole(_senderAddress, FIAT_SETTLEMENT_ROLE) || plan.owner == _senderAddress) {
            revert INVMConfig.InvalidRole(_senderAddress, FIAT_SETTLEMENT_ROLE);
        }

        if (plan.price.priceType != IAsset.PriceType.FIXED_FIAT_PRICE) {
            revert OnlyPlanWithFiatPrice(_planId, plan.price.priceType);
        }

        // Check if the params are valid
        if (!_areSettlementParamsValid(_params)) revert InvalidSettlementParams(_params);

        // FULFILL THE CONDITION
        $.agreementStore.updateConditionStatus(_agreementId, _conditionId, IAgreement.ConditionState.Fulfilled);
    }

    function _areSettlementParamsValid(bytes[] memory /*_params*/ ) internal pure returns (bool) {
        // TODO: Implemment some level of params validation
        return true;
    }

    function _getFiatSettlementConditionStorage() internal pure returns (FiatSettlementConditionStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := FIAT_SETTLEMENT_CONDITION_STORAGE_LOCATION
        }
    }
}
