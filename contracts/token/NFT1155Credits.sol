// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {ERC1155Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import {IERC2981} from '@openzeppelin/contracts/interfaces/IERC2981.sol';
import {INVMConfig} from '../interfaces/INVMConfig.sol';
import {NFT1155Base} from './NFT1155Base.sol';

contract NFT1155Credits is NFT1155Base {

  function initialize(address _nvmConfigAddress, string memory _name, string memory _symbol) public virtual initializer {
    ERC1155Upgradeable.__ERC1155_init('');
    nvmConfig = INVMConfig(_nvmConfigAddress);
  }

  function mint(
    address _to,
    uint256 _id,
    uint256 _value,
    bytes memory _data
  ) public override virtual {    
    super.mint(_to, _id, _value, _data);
  }

  function mintBatch(
    address _to,
    uint256[] memory _ids,
    uint256[] memory _values,
    bytes memory _data
  ) public override virtual {
    super.mintBatch(_to, _ids, _values, _data);
  }

  function burn(address _from, uint256 _id, uint256 _value) public override virtual {
    super.burn(_from, _id, _value);
  }

  function burnBatch(
    address _from,
    uint256[] memory _ids,
    uint256[] memory _values
  ) public override virtual {
    super.burnBatch(_from, _ids, _values);
  }

}
