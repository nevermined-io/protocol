// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { ITemplate } from '../interfaces/ITemplate.sol';

import { AccessManagedUUPSUpgradeable } from '../proxy/AccessManagedUUPSUpgradeable.sol';
import { AgreementsStore } from './AgreementsStore.sol';

abstract contract BaseTemplate is ITemplate, AccessManagedUUPSUpgradeable {
  // keccak256(abi.encode(uint256(keccak256("nevermined.basetemplate.storage")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant BASE_TEMPLATE_STORAGE_LOCATION =
    0xe216fc96f789fa9c96a1eaa661bfd7aef52752717013e765adce03d67eb13e00;

  /// @custom:storage-location erc7201:nevermined.basetemplate.storage
  struct BaseTemplateStorage {
    AgreementsStore agreementStore;
    address assetsRegistryAddress;
  }

  function _getBaseTemplateStorage() internal pure returns (BaseTemplateStorage storage $) {
    // solhint-disable-next-line no-inline-assembly
    assembly ('memory-safe') {
      $.slot := BASE_TEMPLATE_STORAGE_LOCATION
    }
  }
}
