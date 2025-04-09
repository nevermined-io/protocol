// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC2981 } from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import { INVMConfig } from "../interfaces/INVMConfig.sol";
import { INFT1155 } from "../interfaces/INFT1155.sol";
import { IAsset } from "../interfaces/IAsset.sol";

abstract contract NFT1155Base is ERC1155Upgradeable, OwnableUpgradeable, INFT1155 {
  /**
   * @notice Role allowing to mint credits
   */
  bytes32 public constant CREDITS_MINTER_ROLE = keccak256("CREDITS_MINTER_ROLE");

  /**
   * @notice Role allowing to burn credits
   */
  bytes32 public constant CREDITS_BURNER_ROLE = keccak256("CREDITS_BURNER_ROLE");

  /**
   * @notice Role allowing to transfer credits
   * @dev This role is not used in the current implementation
   */
  bytes32 public constant CREDITS_TRANSFER_ROLE = keccak256("CREDITS_TRANSFER_ROLE");

  // keccak256(abi.encode(uint256(keccak256("nevermined.nft1155base.storage")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant NFT1155_BASE_STORAGE_LOCATION =
    0x5dc28ad3de163acbf47a88082c92b50b1954ae8a6818aca0c0ef6cb317ac6500;

  /// @custom:storage-location erc7201:nevermined.nft1155base.storage
  struct NFT1155BaseStorage {
    INVMConfig nvmConfig;
    IAsset assetsRegistry;
  }

  // solhint-disable-next-line func-name-mixedcase
  function __NFT1155Base_init(
    address _nvmConfigAddress,
    address _assetsRegistryAddress
  ) public onlyInitializing {
    NFT1155BaseStorage storage $ = _getNFT1155BaseStorage();

    $.nvmConfig = INVMConfig(_nvmConfigAddress);
    $.assetsRegistry = IAsset(_assetsRegistryAddress);
  }

  /**
   * It mints credits for a plan.
   * @notice Only the owner of the plan or an account with the CREDITS_MINTER_ROLE can mint credits
   * @notice The payment plan must exists
   * @param _to the receiver of the credits
   * @param _planId the plan id
   * @param _amount the number of credits to mint
   * @param _data additional data to pass to the receiver
   */
  function mint(address _to, uint256 _planId, uint256 _amount, bytes memory _data) public virtual {
    NFT1155BaseStorage storage $ = _getNFT1155BaseStorage();

    IAsset.Plan memory plan = $.assetsRegistry.getPlan(_planId);
    if (plan.lastUpdated == 0) revert IAsset.PlanNotFound(_planId);

    // Only the owner of the plan or an account with the CREDITS_MINTER_ROLE can mint credits
    if (!$.nvmConfig.hasRole(msg.sender, CREDITS_MINTER_ROLE) && plan.owner != msg.sender) {
      revert InvalidRole(msg.sender, CREDITS_MINTER_ROLE);
    }

    _mint(_to, _planId, _amount, _data);
  }

  /**
   * It mints credits in batch.
   * @notice Only the owner of the plan or an account with the CREDITS_MINTER_ROLE can mint credits
   * @notice The payment plan must exists
   * @param _to the receiver of the credits
   * @param _ids the plan ids
   * @param _values the number of credits to mint
   * @param _data additional data to pass to the receiver
   */
  function mintBatch(
    address _to,
    uint256[] memory _ids,
    uint256[] memory _values,
    bytes memory _data
  ) public virtual {
    NFT1155BaseStorage storage $ = _getNFT1155BaseStorage();

    if (!$.nvmConfig.hasRole(msg.sender, CREDITS_MINTER_ROLE)) {
      revert InvalidRole(msg.sender, CREDITS_MINTER_ROLE);
    }

    _mintBatch(_to, _ids, _values, _data);
  }

  /**
   * It burns/redeem credits for a plan.
   * @notice The redemption rules depend on the plan.credits.redemptionType
   * @param _from The address of the account that is getting the credits burned
   * @param _planId the plan id
   * @param _amount the number of credits to burn/redeem
   */
  function burn(address _from, uint256 _planId, uint256 _amount) public virtual {
    NFT1155BaseStorage storage $ = _getNFT1155BaseStorage();

    IAsset.Plan memory plan = $.assetsRegistry.getPlan(_planId);
    if (plan.lastUpdated == 0) revert IAsset.PlanNotFound(_planId);

    if (!_canRedeemCredits(_planId, plan.owner, plan.credits.redemptionType, msg.sender)) {
      revert InvalidRedemptionPermission(_planId, plan.credits.redemptionType, msg.sender);
    }

    uint256 creditsToRedeem = _creditsToRedeem(
      _planId,
      plan.credits.creditsType,
      _amount,
      plan.credits.minAmount,
      plan.credits.maxAmount
    );

    _burn(_from, _planId, creditsToRedeem);
  }

  /**
   * It burns/redeem credits in batch.
   * @param _from the address of the account that is getting the credits burned
   * @param _ids the array of plan ids
   * @param _amounts the array of number of credits to burn/redeem
   */
  function burnBatch(
    address _from,
    uint256[] memory _ids,
    uint256[] memory _amounts
  ) public virtual {
    NFT1155BaseStorage storage $ = _getNFT1155BaseStorage();

    if (!$.nvmConfig.hasRole(msg.sender, CREDITS_BURNER_ROLE)) {
      revert InvalidRole(msg.sender, CREDITS_BURNER_ROLE);
    }

    _burnBatch(_from, _ids, _amounts);
  }

  /**
   * It calculates the number of credits to redeme based on the plan and the credits type
   * @notice The credits to redeem depend on the plan.credits.creditsType
   * @param _planId the identifier of the plan
   * @param _creditsType the type of credits
   * @param _amount the number of credits requested to redeem
   * @param _min the minimum number of credits to redeem configured in the plan
   * @param _max the maximum number of credits to redeem configured in the plan
   * @return the number of credits to redeem
   */
  function _creditsToRedeem(
    uint256 _planId,
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
    revert IAsset.InvalidRedemptionAmount(_planId, _creditsType, _amount);
  }

  function _canRedeemCredits(
    uint256 _planId,
    address _owner,
    IAsset.RedemptionType _redemptionType,
    address _sender
  ) internal view returns (bool) {
    NFT1155BaseStorage storage $ = _getNFT1155BaseStorage();

    if (_redemptionType == IAsset.RedemptionType.ONLY_GLOBAL_ROLE) {
      return $.nvmConfig.hasRole(_sender, CREDITS_BURNER_ROLE);
    } else if (_redemptionType == IAsset.RedemptionType.ONLY_OWNER) {
      return _sender == _owner;
    } else if (_redemptionType == IAsset.RedemptionType.ONLY_PLAN_ROLE) {
      return $.nvmConfig.hasRole(_sender, keccak256(abi.encode(_planId)));
    }
    return false;
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

  function _getNFT1155BaseStorage() internal pure returns (NFT1155BaseStorage storage $) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      $.slot := NFT1155_BASE_STORAGE_LOCATION
    }
  }
}
