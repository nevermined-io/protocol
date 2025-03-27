// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import { AgreementsStore } from './AgreementsStore.sol';

abstract contract BaseTemplate is OwnableUpgradeable {
  AgreementsStore internal agreementStore;

  address internal assetsRegistryAddress;

  /// The `seed` of the agreementId provided is not valid
  /// @param seed The seed provided to generate the agreementId
  error InvalidSeed(bytes32 seed);

  /// The `did` provided is not valid
  /// @param did The unique identifier of the asset related to the agreement being created
  error InvalidDID(bytes32 did);

  /// The `planId` provided is not valid
  /// @param planId The unique identifier of the plan being used in the agreement
  error InvalidPlanId(bytes32 planId);
}
