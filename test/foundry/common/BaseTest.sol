// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { Test } from 'forge-std/Test.sol';
import { AccessManager } from '@openzeppelin/contracts/access/manager/AccessManager.sol';
import { ERC1967Proxy } from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import { UUPSUpgradeable } from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import { ToArrayUtils } from './ToArrayUtils.sol';
import { NVMConfig } from '../../../contracts/NVMConfig.sol';
import { AssetsRegistry } from '../../../contracts/AssetsRegistry.sol';
import { AgreementsStore } from '../../../contracts/agreements/AgreementsStore.sol';
import { PaymentsVault } from '../../../contracts/PaymentsVault.sol';
import { NFT1155Credits } from '../../../contracts/token/NFT1155Credits.sol';
import { NFT1155ExpirableCredits } from '../../../contracts/token/NFT1155ExpirableCredits.sol';
import { LockPaymentCondition } from '../../../contracts/conditions/LockPaymentCondition.sol';
import { TransferCreditsCondition } from '../../../contracts/conditions/TransferCreditsCondition.sol';
import { DistributePaymentsCondition } from '../../../contracts/conditions/DistributePaymentsCondition.sol';
import { FixedPaymentTemplate } from '../../../contracts/agreements/FixedPaymentTemplate.sol';

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
  FixedPaymentTemplate fixedPaymentTemplate;

  function setUp() public virtual {
    _deployContracts();

    vm.startPrank(governor);

    // Grant condition permissions
    nvmConfig.grantCondition(address(lockPaymentCondition));
    nvmConfig.grantCondition(address(transferCreditsCondition));
    nvmConfig.grantCondition(address(distributePaymentsCondition));

    // Grant template permissions
    nvmConfig.grantTemplate(address(fixedPaymentTemplate));

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
      address(nvmConfig),
      toArray(UUPSUpgradeable.upgradeToAndCall.selector),
      UPGRADE_ROLE
    );

    // Grant Upgrade permissions to AgreementsStore
    accessManager.setTargetFunctionRole(
      address(agreementsStore),
      toArray(UUPSUpgradeable.upgradeToAndCall.selector),
      UPGRADE_ROLE
    );

    // Grant Upgrade permissions to AssetsRegistry
    accessManager.setTargetFunctionRole(
      address(assetsRegistry),
      toArray(UUPSUpgradeable.upgradeToAndCall.selector),
      UPGRADE_ROLE
    );

    // Grant Upgrade permissions to NFT1155Credits
    accessManager.setTargetFunctionRole(
      address(nftCredits),
      toArray(UUPSUpgradeable.upgradeToAndCall.selector),
      UPGRADE_ROLE
    );

    // Grant Upgrade permissions to PaymentsVault
    accessManager.setTargetFunctionRole(
      address(paymentsVault),
      toArray(UUPSUpgradeable.upgradeToAndCall.selector),
      UPGRADE_ROLE
    );

    vm.stopPrank();
  }

  function _deployContracts() private {
    // Deploy AccessManager
    accessManager = new AccessManager(owner);

    // Deploy NVMConfig
    nvmConfig = NVMConfig(
      address(
        new ERC1967Proxy(
          address(new NVMConfig()),
          abi.encodeCall(NVMConfig.initialize, (owner, address(accessManager), governor))
        )
      )
    );

    // Deploy AssetsRegistry
    assetsRegistry = AssetsRegistry(
      address(
        new ERC1967Proxy(
          address(new AssetsRegistry()),
          abi.encodeCall(AssetsRegistry.initialize, (address(nvmConfig), address(accessManager)))
        )
      )
    );

    // Deploy AgreementsStore
    agreementsStore = AgreementsStore(
      address(
        new ERC1967Proxy(
          address(new AgreementsStore()),
          abi.encodeCall(AgreementsStore.initialize, (address(nvmConfig), address(accessManager)))
        )
      )
    );

    // Deploy PaymentsVault
    paymentsVault = PaymentsVault(
      payable(
        address(
          new ERC1967Proxy(
            address(new PaymentsVault()),
            abi.encodeCall(PaymentsVault.initialize, (address(nvmConfig), address(accessManager)))
          )
        )
      )
    );

    // Deploy NFT1155Credits
    nftCredits = NFT1155Credits(
      address(
        new ERC1967Proxy(
          address(new NFT1155Credits()),
          abi.encodeCall(
            NFT1155Credits.initialize,
            (
              address(nvmConfig),
              address(accessManager),
              address(assetsRegistry),
              'Nevermined Credits',
              'NVMC'
            )
          )
        )
      )
    );

    // Deploy NFT1155ExpirableCredits
    nftExpirableCredits = NFT1155ExpirableCredits(
      address(
        new ERC1967Proxy(
          address(new NFT1155ExpirableCredits()),
          abi.encodeCall(
            NFT1155ExpirableCredits.initialize,
            (
              address(nvmConfig),
              address(accessManager),
              address(assetsRegistry),
              'Nevermined Expirable Credits',
              'NVMEC'
            )
          )
        )
      )
    );

    // Deploy LockPaymentCondition
    lockPaymentCondition = LockPaymentCondition(
      address(
        new ERC1967Proxy(
          address(new LockPaymentCondition()),
          abi.encodeCall(
            LockPaymentCondition.initialize,
            (
              address(nvmConfig),
              address(0),
              address(assetsRegistry),
              address(agreementsStore),
              address(paymentsVault)
            )
          )
        )
      )
    );

    // Deploy TransferCreditsCondition
    transferCreditsCondition = TransferCreditsCondition(
      address(
        new ERC1967Proxy(
          address(new TransferCreditsCondition()),
          abi.encodeCall(
            TransferCreditsCondition.initialize,
            (address(nvmConfig), address(0), address(assetsRegistry), address(agreementsStore))
          )
        )
      )
    );

    // Deploy DistributePaymentsCondition
    distributePaymentsCondition = DistributePaymentsCondition(
      address(
        new ERC1967Proxy(
          address(new DistributePaymentsCondition()),
          abi.encodeCall(
            DistributePaymentsCondition.initialize,
            (
              address(nvmConfig),
              address(0),
              address(assetsRegistry),
              address(agreementsStore),
              address(paymentsVault)
            )
          )
        )
      )
    );

    // Deploy FixedPaymentTemplate
    fixedPaymentTemplate = FixedPaymentTemplate(
      address(
        new ERC1967Proxy(
          address(new FixedPaymentTemplate()),
          abi.encodeCall(
            FixedPaymentTemplate.initialize,
            (
              address(fixedPaymentTemplate),
              address(0),
              address(assetsRegistry),
              address(agreementsStore),
              address(lockPaymentCondition),
              address(transferCreditsCondition),
              address(distributePaymentsCondition)
            )
          )
        )
      )
    );
  }
}
