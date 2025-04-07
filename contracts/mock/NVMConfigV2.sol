// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {NVMConfig} from "../NVMConfig.sol";

/**
 * @title Nevermined Config V2 contract
 * @author @aaitor
 * @notice This contract extends NVMConfig with new functionality for testing upgrades
 */
contract NVMConfigV2 is NVMConfig {
    // New state variable added at the end of the contract
    string public version;

    /**
     * @notice New function to initialize the version
     * @param _version The version string to set
     */
    function initializeV2(string memory _version) external onlyGovernor(msg.sender) {
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
