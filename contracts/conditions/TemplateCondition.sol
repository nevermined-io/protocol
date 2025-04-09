// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract TemplateCondition is OwnableUpgradeable {
  function hashConditionId(
    bytes32 _agreementId,
    bytes32 _conditionName
  ) public pure returns (bytes32) {
    return keccak256(abi.encode(_agreementId, _conditionName));
  }
}
