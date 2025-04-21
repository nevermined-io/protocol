// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {AssetsRegistry} from '../../../contracts/AssetsRegistry.sol';

import {NVMConfig} from '../../../contracts/NVMConfig.sol';
import {DeployAll, DeployedContracts} from '../../../scripts/deploy/DeployAll.sol';

import {PaymentsVault} from '../../../contracts/PaymentsVault.sol';
import {AgreementsStore} from '../../../contracts/agreements/AgreementsStore.sol';

import {FiatPaymentTemplate} from '../../../contracts/agreements/FiatPaymentTemplate.sol';
import {FixedPaymentTemplate} from '../../../contracts/agreements/FixedPaymentTemplate.sol';
import {DistributePaymentsCondition} from '../../../contracts/conditions/DistributePaymentsCondition.sol';
import {FiatSettlementCondition} from '../../../contracts/conditions/FiatSettlementCondition.sol';
import {LockPaymentCondition} from '../../../contracts/conditions/LockPaymentCondition.sol';
import {TransferCreditsCondition} from '../../../contracts/conditions/TransferCreditsCondition.sol';

import {IAgreement} from '../../../contracts/interfaces/IAgreement.sol';
import {IAsset} from '../../../contracts/interfaces/IAsset.sol';
import {NFT1155Credits} from '../../../contracts/token/NFT1155Credits.sol';
import {NFT1155ExpirableCredits} from '../../../contracts/token/NFT1155ExpirableCredits.sol';
import {ToArrayUtils} from './ToArrayUtils.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {AccessManager} from '@openzeppelin/contracts/access/manager/AccessManager.sol';
import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {Test} from 'forge-std/Test.sol';

abstract contract BaseTest is Test, ToArrayUtils {
    // Roles
    uint64 constant UPGRADE_ROLE = uint64(uint256(keccak256(abi.encode('UPGRADE_ROLE'))));
    bytes32 constant DEPOSITOR_ROLE = keccak256(abi.encode('DEPOSITOR_ROLE'));
    bytes32 constant WITHDRAW_ROLE = keccak256(abi.encode('WITHDRAW_ROLE'));
    bytes32 constant CREDITS_MINTER_ROLE = keccak256(abi.encode('CREDITS_MINTER_ROLE'));

    // Configuration
    uint32 constant UPGRADE_DELAY = 7 days;

    // Addresses
    address owner = makeAddr('owner');
    address upgrader = makeAddr('upgrader');
    address governor = makeAddr('governor');
    address nvmFeeReceiver = makeAddr('nvmFeeReceiver');

    // Contracts
    AccessManager accessManager;
    NVMConfig nvmConfig;
    AssetsRegistry assetsRegistry;
    AgreementsStore agreementsStore;
    PaymentsVault paymentsVault;
    NFT1155Credits nftCredits;
    NFT1155ExpirableCredits nftExpirableCredits;
    LockPaymentCondition lockPaymentCondition;
    TransferCreditsCondition transferCreditsCondition;
    DistributePaymentsCondition distributePaymentsCondition;
    FiatSettlementCondition fiatSettlementCondition;
    FixedPaymentTemplate fixedPaymentTemplate;
    FiatPaymentTemplate fiatPaymentTemplate;

    function setUp() public virtual {
        _deployContracts();

        vm.startPrank(governor);

        // Grant condition permissions
        nvmConfig.grantCondition(address(lockPaymentCondition));
        nvmConfig.grantCondition(address(transferCreditsCondition));
        nvmConfig.grantCondition(address(distributePaymentsCondition));
        nvmConfig.grantCondition(address(fiatSettlementCondition));

        // Grant template permissions
        nvmConfig.grantTemplate(address(fixedPaymentTemplate));
        nvmConfig.grantTemplate(address(fiatPaymentTemplate));

        vm.stopPrank();

        vm.startPrank(owner);

        // Grant Deposit and Withdrawal permissions to Payments Vault
        nvmConfig.grantRole(DEPOSITOR_ROLE, address(lockPaymentCondition));
        nvmConfig.grantRole(WITHDRAW_ROLE, address(distributePaymentsCondition));

        // Grant Mint permissions to transferNFTCondition on NFT1155Credits contracts
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(transferCreditsCondition));

        // Grant Mint permissions to transferNFTCondition on NFT1155ExpirableCredits contracts
        nvmConfig.grantRole(CREDITS_MINTER_ROLE, address(transferCreditsCondition));

        // Grant Upgrade permissions to upgrader
        accessManager.grantRole(UPGRADE_ROLE, address(upgrader), UPGRADE_DELAY);

        // Grant Upgrade permissions to NVMConfig
        accessManager.setTargetFunctionRole(
            address(nvmConfig), toArray(UUPSUpgradeable.upgradeToAndCall.selector), UPGRADE_ROLE
        );

        // Grant Upgrade permissions to AgreementsStore
        accessManager.setTargetFunctionRole(
            address(agreementsStore), toArray(UUPSUpgradeable.upgradeToAndCall.selector), UPGRADE_ROLE
        );

        // Grant Upgrade permissions to AssetsRegistry
        accessManager.setTargetFunctionRole(
            address(assetsRegistry), toArray(UUPSUpgradeable.upgradeToAndCall.selector), UPGRADE_ROLE
        );

        // Grant Upgrade permissions to NFT1155Credits
        accessManager.setTargetFunctionRole(
            address(nftCredits), toArray(UUPSUpgradeable.upgradeToAndCall.selector), UPGRADE_ROLE
        );

        // Grant Upgrade permissions to PaymentsVault
        accessManager.setTargetFunctionRole(
            address(paymentsVault), toArray(UUPSUpgradeable.upgradeToAndCall.selector), UPGRADE_ROLE
        );

        vm.stopPrank();
    }

    function _deployContracts() internal virtual {
        // Set the addresses
        vm.setEnv('GOVERNOR_ADDRESS', vm.toString(governor));
        vm.setEnv('OWNER_ADDRESS', vm.toString(owner));

        // Deploy the contracts
        DeployedContracts memory deployed = new DeployAll().run();

        accessManager = deployed.accessManager;
        nvmConfig = deployed.nvmConfig;
        assetsRegistry = deployed.assetsRegistry;
        agreementsStore = deployed.agreementsStore;
        paymentsVault = deployed.paymentsVault;
        nftCredits = deployed.nftCredits;
        nftExpirableCredits = deployed.nftExpirableCredits;
        lockPaymentCondition = deployed.lockPaymentCondition;
        transferCreditsCondition = deployed.transferCreditsCondition;
        distributePaymentsCondition = deployed.distributePaymentsCondition;
        fiatSettlementCondition = deployed.fiatSettlementCondition;
    }

    function _grantTemplateRole(address _caller) internal virtual {
        _grantNVMConfigRole(nvmConfig.CONTRACT_TEMPLATE_ROLE(), _caller);
    }

    function _grantNVMConfigRole(bytes32 _role, address _caller) internal virtual {
        vm.startPrank(owner);
        nvmConfig.grantRole(_role, _caller);
        vm.stopPrank();
    }

    function _createAgreement(address _caller, uint256 _planId) internal virtual returns (bytes32) {
        bytes32[] memory conditionIds = new bytes32[](1);
        IAgreement.ConditionState[] memory conditionStates = new IAgreement.ConditionState[](1);

        conditionIds[0] = keccak256('abc');
        conditionStates[0] = IAgreement.ConditionState.Unfulfilled;

        _grantTemplateRole(address(this));
        bytes32 agreementId = keccak256('123');
        agreementsStore.register(agreementId, _caller, _planId, conditionIds, conditionStates, new bytes[](0));
        return agreementId;
    }

    function _createPlan() internal returns (uint256) {
        uint256 nonce = block.number;
        return _createPlan(nonce);
    }

    function _createPlan(uint256 nonce) internal returns (uint256) {
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 100;
        address[] memory _receivers = new address[](1);
        _receivers[0] = address(this);

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

        address nftAddress = address(nftCredits);
        assetsRegistry.createPlan(priceConfig, creditsConfig, nftAddress, nonce);
        return assetsRegistry.hashPlanId(priceConfig, creditsConfig, nftAddress, address(this), nonce);
    }

    function _registerAsset(uint256 _planId) internal returns (bytes32) {
        uint256[] memory planIds = new uint256[](1);
        planIds[0] = _planId;

        // Get the DID that will be generated
        bytes32 did = assetsRegistry.hashDID('test-did', address(this));

        vm.prank(address(this));
        vm.expectEmit(true, true, false, false);
        emit IAsset.AssetRegistered(did, address(this));

        assetsRegistry.register('test-did', 'https://example.com', planIds);
        return did;
    }

    function _createExpirablePlan(uint256 amount, uint256 durationSecs) internal returns (uint256) {
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = 100;
        address[] memory _receivers = new address[](1);
        _receivers[0] = owner;

        (uint256[] memory amounts, address[] memory receivers) =
            assetsRegistry.addFeesToPaymentsDistribution(_amounts, _receivers);

        IAsset.PriceConfig memory priceConfig = IAsset.PriceConfig({
            priceType: IAsset.PriceType.FIXED_PRICE,
            tokenAddress: address(0),
            amounts: amounts,
            receivers: receivers,
            contractAddress: address(0)
        });

        IAsset.CreditsConfig memory creditsConfig = IAsset.CreditsConfig({
            creditsType: IAsset.CreditsType.EXPIRABLE,
            redemptionType: IAsset.RedemptionType.ONLY_GLOBAL_ROLE,
            durationSecs: durationSecs,
            amount: amount,
            minAmount: 1,
            maxAmount: amount
        });

        vm.prank(owner);
        assetsRegistry.createPlan(priceConfig, creditsConfig, address(nftExpirableCredits));
        return assetsRegistry.hashPlanId(priceConfig, creditsConfig, address(nftExpirableCredits), owner);
    }
}
