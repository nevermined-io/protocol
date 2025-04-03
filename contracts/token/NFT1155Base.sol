// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { ERC1155Upgradeable } from '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import { OwnableUpgradeable } from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import { IERC2981 } from '@openzeppelin/contracts/interfaces/IERC2981.sol';
import { INVMConfig } from '../interfaces/INVMConfig.sol';
import { IAsset } from '../interfaces/IAsset.sol';

abstract contract NFT1155Base is ERC1155Upgradeable, OwnableUpgradeable {
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

  IAsset internal assetsRegistry;

  /// Only an account with the right role can access this function
  /// @param sender The address of the account calling this function
  /// @param role The role required to call this function
  error InvalidRole(address sender, bytes32 role);

  /// The redemption permissions of the plan with id `planId` are not valid for the account `sender`
  /// @param planId The identifier of the plan
  /// @param redeemptionType The type of redemptions that can be used for the plan
  /// @param sender The address of the account calling this function
  error InvalidRedemptionPermission(
    bytes32 planId,
    IAsset.RedeemptionType redeemptionType,
    address sender
  );

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

  function burn(address _from, uint256 _id, uint256 _amount) public virtual {
    bytes32 planId = bytes32(_id);
    IAsset.Plan memory plan = assetsRegistry.getPlan(planId);
    if (plan.lastUpdated == 0) revert IAsset.PlanNotFound(planId);

    if (!_canRedeemCredits(planId, plan.owner, plan.credits.redemptionType, msg.sender))
      revert InvalidRedemptionPermission(planId, plan.credits.redemptionType, msg.sender);

    uint256 creditsToRedeem = _creditsToRedeem(
      planId,
      plan.credits.creditsType,
      _amount,
      plan.credits.minAmount,
      plan.credits.maxAmount
    );

    _burn(_from, _id, creditsToRedeem);
  }

  function _creditsToRedeem(
    bytes32 _planId,
    IAsset.CreditsType _creditsType,
    uint256 _amount,
    uint256 _min,
    uint256 _max
  ) internal pure returns (uint256) {
    if (_creditsType == IAsset.CreditsType.DYNAMIC) {
      if (_amount < _min || _amount > _max) return _min;
      else return _amount;
    } else if (_creditsType == IAsset.CreditsType.FIXED) {
      return _min;
    } else if (_creditsType == IAsset.CreditsType.EXPIRABLE) {
      return 1;
    }
    revert IAsset.InvalidRedeemptionAmount(_planId, _creditsType, _amount);
  }

  function _canRedeemCredits(
    bytes32 _planId,
    address _owner,
    IAsset.RedeemptionType _redemptionType,
    address _sender
  ) internal view returns (bool) {
    if (_redemptionType == IAsset.RedeemptionType.ONLY_GLOBAL_ROLE) {
      return nvmConfig.hasRole(_sender, CREDITS_BURNER_ROLE);
    } else if (_redemptionType == IAsset.RedeemptionType.ONLY_OWNER) {
      return _sender == _owner;
    } else if (_redemptionType == IAsset.RedeemptionType.ONLY_PLAN_ROLE) {
      return nvmConfig.hasRole(_sender, _planId);
    }
    return false;
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
