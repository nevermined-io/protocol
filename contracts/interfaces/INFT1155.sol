// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { IAsset } from "../interfaces/IAsset.sol";

interface INFT1155 {
  /// Only an account with the right role can access this function
  /// @param sender The address of the account calling this function
  /// @param role The role required to call this function
  error InvalidRole(address sender, bytes32 role);

  /// The redemption permissions of the plan with id `planId` are not valid for the account `sender`
  /// @param planId The identifier of the plan
  /// @param redemptionType The type of redemptions that can be used for the plan
  /// @param sender The address of the account calling this function
  error InvalidRedemptionPermission(
    uint256 planId,
    IAsset.RedemptionType redemptionType,
    address sender
  );

  /// The lentgh of the ids and values arrays must be the same
  /// @param idsLength The length of the ids array
  /// @param valuesLength The length of the values array
  error InvalidLength(uint256 idsLength, uint256 valuesLength);
}
