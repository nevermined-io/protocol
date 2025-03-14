// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import {AccessControlUpgradeable} from '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import {IERC2981} from '@openzeppelin/contracts/interfaces/IERC2981.sol';
import {INVMConfig} from '../interfaces/INVMConfig.sol';

abstract contract NFT1155Credits is
  ERC1155Upgradeable,
  AccessControlUpgradeable
{
  /**
   * @notice Role allowing to mint credits
   */
  bytes32 public constant CREDITS_MINTER_ROLE =
    keccak256('CREDITS_MINTER_ROLE');

  /**
   * @notice Role allowing to mint credits
   */
  bytes32 public constant CREDITS_BURNER_ROLE =
    keccak256('CREDITS_MINTER_ROLE');

  INVMConfig internal nvmConfig;

  function initialize(address _nvmConfigAddress) public virtual initializer {
    nvmConfig = INVMConfig(_nvmConfigAddress);
  }

  function supportsInterface(
    bytes4 interfaceId
  )
    public
    view
    virtual
    override(ERC1155Upgradeable, AccessControlUpgradeable)
    returns (bool)
  {
    return
      AccessControlUpgradeable.supportsInterface(interfaceId) ||
      ERC1155Upgradeable.supportsInterface(interfaceId) ||
      interfaceId == type(IERC2981).interfaceId;
  }
}
