// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {AgreementsStore} from '../agreements/AgreementsStore.sol';
import {INVMConfig} from '../interfaces/INVMConfig.sol';

/**
 * @title Nevermined Agreements Store V2 contract
 * @author @aaitor
 * @notice This contract extends AgreementsStore with new functionality for testing upgrades
 */
contract AgreementsStoreV2 is AgreementsStore {
  // New state variable added at the end of the contract
  string public version;
  
  /**
   * @notice New function to initialize the version
   * @param _version The version string to set
   */
  function initializeV2(string memory _version) external {
    if (!nvmConfig.isGovernor(msg.sender))
      revert INVMConfig.OnlyGovernor(msg.sender);
    version = _version;
  }
  
  /**
   * @notice New function to get the version
   * @return The current version string
   */
  function getVersion() external view returns (string memory) {
    return version;
  }
}
