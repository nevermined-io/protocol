// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { ERC1155Upgradeable } from '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import { IERC2981 } from '@openzeppelin/contracts/interfaces/IERC2981.sol';
import { INVMConfig } from '../interfaces/INVMConfig.sol';

abstract contract NFT1155Base is ERC1155Upgradeable {
  /**
   * @notice Role allowing to mint credits
   */
  bytes32 public constant CREDITS_MINTER_ROLE = keccak256('CREDITS_MINTER_ROLE');

  /**
   * @notice Role allowing to burn credits
   */
  bytes32 public constant CREDITS_BURNER_ROLE = keccak256('CREDITS_BURNER_ROLE');

  /**
   * @notice Role allowing to transfer credits
   * @dev This role is not used in the current implementation
   */
  bytes32 public constant CREDITS_TRANSFER_ROLE = keccak256('CREDITS_TRANSFER_ROLE');

  INVMConfig internal nvmConfig;

  /// Only an account with the right role can access this function
  /// @param sender The address of the account calling this function
  /// @param role The role required to call this function
  error InvalidRole(address sender, bytes32 role);

  function mint(address _to, uint256 _id, uint256 _value, bytes memory _data) public virtual {
    if (!nvmConfig.hasRole(msg.sender, CREDITS_MINTER_ROLE))
      revert InvalidRole(msg.sender, CREDITS_MINTER_ROLE);

    _mint(_to, _id, _value, _data);
  }

  function mintBatch(
    address _to,
    uint256[] memory _ids,
    uint256[] memory _values,
    bytes memory _data
  ) public virtual {
    if (!nvmConfig.hasRole(msg.sender, CREDITS_MINTER_ROLE))
      revert InvalidRole(msg.sender, CREDITS_MINTER_ROLE);

    _mintBatch(_to, _ids, _values, _data);
  }

  function burn(address _from, uint256 _id, uint256 _value) public virtual {
    if (!nvmConfig.hasRole(msg.sender, CREDITS_BURNER_ROLE))
      revert InvalidRole(msg.sender, CREDITS_BURNER_ROLE);

    _burn(_from, _id, _value);
  }

  function burnBatch(
    address _from,
    uint256[] memory _ids,
    uint256[] memory _values
  ) public virtual {
    if (!nvmConfig.hasRole(msg.sender, CREDITS_BURNER_ROLE))
      revert InvalidRole(msg.sender, CREDITS_BURNER_ROLE);

    _burnBatch(_from, _ids, _values);
  }

  //@solhint-disable-next-line
  function safeTransferFrom(
    address /*from*/,
    address /*to*/,
    uint256 /*id*/,
    uint256 /*value*/,
    bytes memory /*data*/
  ) public virtual override {
    revert InvalidRole(msg.sender, CREDITS_TRANSFER_ROLE);
  }

  //@solhint-disable-next-line
  function safeBatchTransferFrom(
    address /*from*/,
    address /*to*/,
    uint256[] memory /*ids*/,
    uint256[] memory /*values*/,
    bytes memory /*data*/
  ) public virtual override {
    revert InvalidRole(msg.sender, CREDITS_TRANSFER_ROLE);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return
      ERC1155Upgradeable.supportsInterface(interfaceId) ||
      interfaceId == type(IERC2981).interfaceId;
  }
}
