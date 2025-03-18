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


  function register(
    bytes32 _didSeed,
    string memory _url,
    bytes32[] memory _plans
  ) public virtual {
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

  function createPlan(
    PriceConfig memory _priceConfig,
    CreditsConfig memory _creditsConfig,
    address _nftAddress
  ) public {
    bytes32 planId = hashPlanId(
      _priceConfig,
      _creditsConfig,
      _nftAddress,
      msg.sender
    );
    if (plans[planId].lastUpdated != 0) {
      revert PlanAlreadyRegistered(planId);
    }
    if (!this.areNeverminedFeesIncluded(_priceConfig.amounts, _priceConfig.receivers)) {
      revert NeverminedFeesNotIncluded(
        _priceConfig.amounts,
        _priceConfig.receivers
      );
    }
    
    plans[planId] = Plan({
      price: _priceConfig,
      credits: _creditsConfig,
      nftAddress: _nftAddress,
      lastUpdated: block.timestamp
    });
    emit PlanRegistered(planId, msg.sender);
  }

  function registerAssetAndPlan(
    bytes32 _didSeed,
    string memory _url,
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
    if (!this.planExists(planId)) {
      createPlan(_priceConfig, _creditsConfig, _nftAddress);
    }    
    
    bytes32[] memory _assetPlans = new bytes32[](1);
    _assetPlans[0] = planId;
    register(_didSeed, _url, _assetPlans);
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

  function areNeverminedFeesIncluded(
    uint256[] memory _amounts,
    address[] memory _receivers
  ) external view returns (bool) {
    if (
      nvmConfig.getNetworkFee() == 0 || nvmConfig.getFeeReceiver() == address(0)
    ) return true;

    
    uint256 totalAmount = 0;
    for (uint256 i; i < _amounts.length; i++) totalAmount += _amounts[i];

    if (totalAmount == 0) return true;

    bool _feeReceiverIncluded = false;
    uint256 _receiverIndex = 0;

    for (uint256 i = 0; i < _receivers.length; i++) {
      if (_receivers[i] == nvmConfig.getFeeReceiver()) {
        _feeReceiverIncluded = true;
        _receiverIndex = i;
      }
    }
    if (!_feeReceiverIncluded) return false;

    // Return if fee calculation is correct
    return _calculateFeeAmount(
      nvmConfig.getNetworkFee(),
      totalAmount,
      nvmConfig.getFeeDenominator()
    ) == _amounts[_receiverIndex];
    // return
    //   (nvmConfig.getNetworkFee() * totalAmount) /
    //     nvmConfig.getFeeDenominator() ==
    //   _amounts[_receiverIndex];
  }

  function addFeesToPaymentsDistribution(
    uint256[] memory _amounts,
    address[] memory _receivers
  ) external view returns (uint256[] memory amounts, address[] memory receivers) {
    // If the fees are already added we don't need to do anything
    if (this.areNeverminedFeesIncluded(_amounts, _receivers)) return ( _amounts, _receivers );

    uint256 totalAmount = 0;
    for (uint256 i; i < _amounts.length; i++) totalAmount += _amounts[i];

    // If the total amount is zero we don't need to add fees
    if (totalAmount == 0) return ( _amounts, _receivers );

    uint256 feeAmount = _calculateFeeAmount(
      nvmConfig.getNetworkFee(),
      totalAmount,
      nvmConfig.getFeeDenominator()
    );

    uint256 _length = _amounts.length;
    
    uint256[] memory amountsWithFees = new uint256[](_length + 1);
    for (uint256 i; i < _amounts.length; i++) amountsWithFees[i] = _amounts[i];
    amountsWithFees[_length] = feeAmount;

    address[] memory receiversWithFees = new address[](_length + 1);
    for (uint256 i; i < _receivers.length; i++) receiversWithFees[i] = _receivers[i];
    receiversWithFees[_length] = nvmConfig.getFeeReceiver();

    return ( amountsWithFees, receiversWithFees );
  }

  function _calculateFeeAmount(uint256 _feeAmount, uint256 _totalAmount, uint256 _feeDenominator) internal pure returns (uint256) {
    return (_feeAmount * _totalAmount) / _feeDenominator;
  }
}
