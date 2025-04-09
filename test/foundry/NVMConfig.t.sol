// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { Test, console } from 'forge-std/Test.sol';
import { NVMConfig } from '../../contracts/NVMConfig.sol';

contract NVMConfigTest is Test {
  NVMConfig public nvmConfig;
  address public owner;

  function setUp() public {
    nvmConfig = new NVMConfig();
    owner = address(this);
    nvmConfig.initialize(owner, address(0x1), owner); // TODO: add authority
    nvmConfig.setNetworkFees(100, owner);
  }

  function test_getNetworkFee() public view {
    uint256 networkFee = nvmConfig.getNetworkFee();
    assertEq(networkFee, 100);
  }

  function test_getFeeReceiver() public view {
    address feeReceiver = nvmConfig.getFeeReceiver();
    assertEq(feeReceiver, owner);
  }
}
