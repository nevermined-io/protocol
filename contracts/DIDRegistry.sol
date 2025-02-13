// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';

contract DIDRegistry is AccessControlUpgradeable {
  bytes32 public constant OWNER_ROLE = keccak256('REGISTRY_OWNER');

  struct DIDAsset {
    // The owner of the asset
    address owner;
    // Asset original creator, this can't be modified after the asset is registered
    address creator;
    // URL to the metadata associated to the DID
    string url;
    // Who was the last one updated the entry
    address lastUpdatedBy;
  }

  mapping(bytes32 => DIDAsset) public assets;

  /// The DID `did` is already registered
  /// @param did The identifier to register
  error DIDAlreadyRegistered(bytes32 did);

  function initialize(address _owner) public initializer {
    AccessControlUpgradeable.__AccessControl_init();
    AccessControlUpgradeable._grantRole(OWNER_ROLE, _owner);
  }

  function register(
    bytes32 _didSeed,
    string memory _url,
    address[] memory _providers,
    bytes32 _checksum,
    string memory _metadata
  ) public virtual {
    bytes32 _did = hashDID(_didSeed, _msgSender());
    if (assets[_did].owner != address(0x0)) {
      revert DIDAlreadyRegistered(_did);
    }
    // assets.
  }

  /**
   * @notice It generates a DID using as seed a bytes32 and the address of the DID creator
   * @param _didSeed refers to DID Seed used as base to generate the final DID
   * @param _creator address of the creator of the DID
   * @return the new DID created
   */
  function hashDID(
    bytes32 _didSeed,
    address _creator
  ) public pure returns (bytes32) {
    return keccak256(abi.encode(_didSeed, _creator));
  }
}
