// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
// import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {AgreementsStore} from './AgreementsStore.sol';

abstract contract BaseTemplate is Initializable {
  AgreementsStore internal agreementStore;

  address internal assetsRegistryAddress;

  function __createAgreementAndLockPayment(
    bytes32 _seed,
    bytes32 _did,
    bytes32 _planId
  ) public payable {
    // STEPS:
    // 1. Check if the agreement is already registered
    // 2. Register the agreement in the AgreementsStore
    // 3. Lock the payment
    //agreementStore.register(_seed, _did, _planId);
  }
}
