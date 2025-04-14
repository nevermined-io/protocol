// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { IAsset } from '../interfaces/IAsset.sol';

interface IFiatSettlement {
  /// The settlement params specified are invalid
  /// @param params Settlement params provided
  error InvalidSettlementParams(bytes[] params);

  /// This condition only can be fulfilled for plans where the price type is FIXED_FIAT_PRICE
  /// @param planId The identifier of the plan
  /// @param priceType The type of price of the plan
  error OnlyPlanWithFiatPrice(uint256 planId, IAsset.PriceType priceType);
}
