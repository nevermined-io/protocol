// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {INVMConfig} from './interfaces/INVMConfig.sol';
import {IAsset} from './interfaces/IAsset.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
// import 'hardhat/console.sol';

contract AssetsRegistry is Initializable, IAsset {
  bytes32 public constant OWNER_ROLE = keccak256('REGISTRY_OWNER');

  INVMConfig internal nvmConfig;

  mapping(bytes32 => DIDAsset) public assets;



  /// The mapping of the plans registered in the contract
  mapping(bytes32 => Plan) public plans;


  /**
   * @notice Event that is emitted when a new Asset is registered
   * @param did the unique identifier of the asset
   * @param creator the address of the account registering the asset
   */
  event AssetRegistered(bytes32 indexed did, address indexed creator);

  /**
   * @notice Event that is emitted when a new plan is registered
   * @param planId the unique identifier of the plan
   * @param creator the address of the account registering the plan
   */
  event PlanRegistered(bytes32 indexed planId, address indexed creator);

  /// A plan with the same `plainId` is already registered and can not be registered again.abi
  /// The `planId` is computed using the hash of the `PriceConfig`, `CreditsConfig`, `nftAddress` and the creator of the plan
  /// @param planId The identifier of the plan
  error PlanAlreadyRegistered(bytes32 planId);

  /// The DID `did` representing the key for an Asset is already registered
  /// @param did The identifier of the asset to register
  error DIDAlreadyRegistered(bytes32 did);

  /// When registering the asset, the plans array is empty
  /// @param did The identifier to register
  error NotPlansAttached(bytes32 did);

  function initialize(address _nvmConfigAddress) public initializer {
    nvmConfig = INVMConfig(_nvmConfigAddress);
    // console.log('AssetsRegistry initialized', _nvmConfigAddress);
  }

  function register(
    bytes32 _didSeed,
    string memory _url,
    bytes32[] memory _plans
  ) external virtual {
    bytes32 did = hashDID(_didSeed, msg.sender);
    if (assets[did].owner != address(0x0)) {
      revert DIDAlreadyRegistered(did);
    }

    if (_plans.length == 0) {
      revert NotPlansAttached(did);
    }
    assets[did] = DIDAsset({
      owner: msg.sender,
      creator: msg.sender,
      url: _url,
      lastUpdated: block.timestamp,
      plans: _plans
    });

    emit AssetRegistered(did, msg.sender);
  }

  function getAsset(bytes32 _did) external view returns (DIDAsset memory) {
    return assets[_did];
  }

  function assetExists(bytes32 _did) external view returns (bool) {
    return assets[_did].lastUpdated != 0;
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

  function createPlan(
    PriceConfig memory _priceConfig,
    CreditsConfig memory _creditsConfig,
    address _nftAddress
  ) external {
    bytes32 planId = hashPlanId(
      _priceConfig,
      _creditsConfig,
      _nftAddress,
      msg.sender
    );
    if (plans[planId].lastUpdated != 0) {
      revert PlanAlreadyRegistered(planId);
    }
    plans[planId] = Plan({
      price: _priceConfig,
      credits: _creditsConfig,
      nftAddress: _nftAddress,
      lastUpdated: block.timestamp
    });
    emit PlanRegistered(planId, msg.sender);
  }

  function getPlan(bytes32 _planId) public view returns (Plan memory) {
    return plans[_planId];
  }

  function planExists(bytes32 _planId) external view returns (bool) {
    return plans[_planId].lastUpdated != 0;
  }


  /**
   * Given the plan attributes and the address of the plan creator, it computes a unique identifier for the plan
   * @param _priceConfig the price configuration of the plan
   * @param _creditsConfig the credits configuration of the plan
   * @param _nftAddress the address of the NFT contract that represents the plan
   * @param _creator the address of the user that created the plan
   * @return the unique identifier of the plan
   */
  function hashPlanId(
    PriceConfig memory _priceConfig,
    CreditsConfig memory _creditsConfig,
    address _nftAddress,
    address _creator
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encode(_priceConfig, _creditsConfig, _nftAddress, _creator)
      );
  }
}
