// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

struct UpgradeableContractDeploySalt {
    bytes32 proxySalt;
    bytes32 implementationSalt;
}
