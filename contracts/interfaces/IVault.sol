// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

interface IVault {
  function deposit(uint256 assets, address receiver) external returns (uint256);
  function mint(uint256 shares, address receiver) external returns (uint256);
  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  ) external returns (uint256);
}
