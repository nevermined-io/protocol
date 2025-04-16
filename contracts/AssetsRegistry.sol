// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {IAsset} from './interfaces/IAsset.sol';
import {INVMConfig} from './interfaces/INVMConfig.sol';
import {AccessManagedUUPSUpgradeable} from './proxy/AccessManagedUUPSUpgradeable.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';

contract AssetsRegistry is IAsset, AccessManagedUUPSUpgradeable {
    // keccak256(abi.encode(uint256(keccak256("nevermined.assetsregistry.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ASSETS_REGISTRY_STORAGE_LOCATION =
        0x6c9566430157c5ec4491fdbbed7bf67f82d06a6dee70d9aaa3ede461d7d98900;

    bytes32 public constant OWNER_ROLE = keccak256('REGISTRY_OWNER');

    /// @custom:storage-location erc7201:nevermined.assetsregistry.storage
    struct AssetsRegistryStorage {
        INVMConfig nvmConfig;
        mapping(bytes32 => DIDAsset) assets;
        /// The mapping of the plans registered in the contract
        mapping(uint256 => Plan) plans;
    }

    function initialize(INVMConfig _nvmConfigAddress, IAccessManager _authority) external initializer {
        _getAssetsRegistryStorage().nvmConfig = _nvmConfigAddress;
        __AccessManagedUUPSUpgradeable_init(address(_authority));
    }

    function getAsset(bytes32 _did) external view returns (DIDAsset memory) {
        return _getAssetsRegistryStorage().assets[_did];
    }

    function assetExists(bytes32 _did) external view returns (bool) {
        return _getAssetsRegistryStorage().assets[_did].lastUpdated != 0;
    }

    /**
     * @notice It generates a DID using as seed a bytes32 and the address of the DID creator
     * @param _didSeed refers to DID Seed used as base to generate the final DID
     * @param _creator address of the creator of the DID
     * @return the new DID created
     */
    function hashDID(bytes32 _didSeed, address _creator) public pure returns (bytes32) {
        return keccak256(abi.encode(_didSeed, _creator));
    }

    function register(bytes32 _didSeed, string memory _url, uint256[] memory _plans) public virtual {
        AssetsRegistryStorage storage $ = _getAssetsRegistryStorage();

        bytes32 did = hashDID(_didSeed, msg.sender);
        if ($.assets[did].owner != address(0x0)) {
            revert DIDAlreadyRegistered(did);
        }

        if (_plans.length == 0) {
            revert NotPlansAttached(did);
        }
        $.assets[did] =
            DIDAsset({owner: msg.sender, creator: msg.sender, url: _url, lastUpdated: block.timestamp, plans: _plans});

        emit AssetRegistered(did, msg.sender);
    }

    function createPlan(PriceConfig memory _priceConfig, CreditsConfig memory _creditsConfig, address _nftAddress)
        external
    {
        _createPlan(msg.sender, _priceConfig, _creditsConfig, _nftAddress, 0);
    }

    function createPlan(
        PriceConfig memory _priceConfig,
        CreditsConfig memory _creditsConfig,
        address _nftAddress,
        uint256 _nonce
    ) external {
        _createPlan(msg.sender, _priceConfig, _creditsConfig, _nftAddress, _nonce);
    }

    function registerAssetAndPlan(
        bytes32 _didSeed,
        string memory _url,
        PriceConfig memory _priceConfig,
        CreditsConfig memory _creditsConfig,
        address _nftAddress
    ) external {
        uint256 planId = hashPlanId(_priceConfig, _creditsConfig, _nftAddress, msg.sender);
        if (!this.planExists(planId)) {
            _createPlan(msg.sender, _priceConfig, _creditsConfig, _nftAddress, 0);
        }

        uint256[] memory _assetPlans = new uint256[](1);
        _assetPlans[0] = planId;
        register(_didSeed, _url, _assetPlans);
    }

    function _createPlan(
        address _owner,
        PriceConfig memory _priceConfig,
        CreditsConfig memory _creditsConfig,
        address _nftAddress,
        uint256 _nonce
    ) internal {
        AssetsRegistryStorage storage $ = _getAssetsRegistryStorage();

        uint256 planId = hashPlanId(_priceConfig, _creditsConfig, _nftAddress, _owner, _nonce);
        if ($.plans[planId].lastUpdated != 0) {
            revert PlanAlreadyRegistered(planId);
        }

        // If the price type is FIXED_PRICE, we need to check if the Nevermined fees are included in the payment distribution
        if (
            _priceConfig.priceType == IAsset.PriceType.FIXED_PRICE
                && !this.areNeverminedFeesIncluded(_priceConfig.amounts, _priceConfig.receivers)
        ) {
            revert NeverminedFeesNotIncluded(_priceConfig.amounts, _priceConfig.receivers);
        }

        $.plans[planId] = Plan({
            owner: _owner,
            price: _priceConfig,
            credits: _creditsConfig,
            nftAddress: _nftAddress,
            lastUpdated: block.timestamp
        });
        emit PlanRegistered(planId, _owner);
    }

    function getPlan(uint256 _planId) external view returns (Plan memory) {
        return _getAssetsRegistryStorage().plans[_planId];
    }

    function planExists(uint256 _planId) external view returns (bool) {
        return _getAssetsRegistryStorage().plans[_planId].lastUpdated != 0;
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
        address _creator,
        uint256 _nonce
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(_priceConfig, _creditsConfig, _nftAddress, _creator, _nonce)));
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
    ) public pure returns (uint256) {
        return hashPlanId(_priceConfig, _creditsConfig, _nftAddress, _creator, 0);
    }

    /**
     * @notice Add a new plan to an asset. This can only be done by the asset owner.
     * @param _did the unique identifier of the asset
     * @param _planId the unique identifier of the plan to add
     */
    function addPlanToAsset(bytes32 _did, uint256 _planId) external {
        AssetsRegistryStorage storage $ = _getAssetsRegistryStorage();

        if ($.assets[_did].lastUpdated == 0) {
            revert AssetNotFound(_did);
        }

        if ($.assets[_did].owner != msg.sender) {
            revert NotAssetOwner(_did, msg.sender, $.assets[_did].owner);
        }

        if ($.plans[_planId].lastUpdated == 0) {
            revert PlanNotFound(_planId);
        }

        // Check if plan is already in the asset's plans array
        uint256[] memory currentPlans = $.assets[_did].plans;
        for (uint256 i = 0; i < currentPlans.length; i++) {
            if (currentPlans[i] == _planId) {
                // Plan is already in the list, nothing to do
                return;
            }
        }

        // Add plan to the asset's plans array
        $.assets[_did].plans.push(_planId);
        $.assets[_did].lastUpdated = block.timestamp;

        emit PlanAddedToAsset(_did, _planId, msg.sender);
    }

    /**
     * @notice Remove a plan from an asset. This can only be done by the asset owner.
     * @param _did the unique identifier of the asset
     * @param _planId the unique identifier of the plan to remove
     */
    function removePlanFromAsset(bytes32 _did, uint256 _planId) external {
        AssetsRegistryStorage storage $ = _getAssetsRegistryStorage();

        if ($.assets[_did].lastUpdated == 0) {
            revert AssetNotFound(_did);
        }

        if ($.assets[_did].owner != msg.sender) {
            revert NotAssetOwner(_did, msg.sender, $.assets[_did].owner);
        }

        uint256[] storage plans = $.assets[_did].plans;
        bool found = false;
        uint256 indexToRemove;

        // Find the index of the plan to remove
        for (uint256 i = 0; i < plans.length; i++) {
            if (plans[i] == _planId) {
                found = true;
                indexToRemove = i;
                break;
            }
        }

        if (!found) {
            revert PlanNotInAsset(_did, _planId);
        }

        // Remove the plan by swapping with the last element and popping
        if (indexToRemove != plans.length - 1) {
            plans[indexToRemove] = plans[plans.length - 1];
        }
        plans.pop();

        // Update the lastUpdated timestamp
        $.assets[_did].lastUpdated = block.timestamp;

        emit PlanRemovedFromAsset(_did, _planId, msg.sender);
    }

    /**
     * @notice Replace all plans for an asset with a new set of plans. This can only be done by the asset owner.
     * @param _did the unique identifier of the asset
     * @param _plans the new array of plan IDs to associate with the asset
     */
    function replacePlansForAsset(bytes32 _did, uint256[] memory _plans) external {
        AssetsRegistryStorage storage $ = _getAssetsRegistryStorage();

        if ($.assets[_did].lastUpdated == 0) {
            revert AssetNotFound(_did);
        }

        if ($.assets[_did].owner != msg.sender) {
            revert NotAssetOwner(_did, msg.sender, $.assets[_did].owner);
        }

        // Validate that all plans exist
        for (uint256 i = 0; i < _plans.length; i++) {
            if ($.plans[_plans[i]].lastUpdated == 0) {
                revert PlanNotFound(_plans[i]);
            }
        }

        // Replace the plans
        $.assets[_did].plans = _plans;
        $.assets[_did].lastUpdated = block.timestamp;

        emit AssetPlansReplaced(_did, msg.sender);
    }

    /**
     * @notice Transfers the ownership of an asset to a new owner
     * @param _did The identifier of the asset
     * @param _newOwner The address of the new owner
     */
    function transferAssetOwnership(bytes32 _did, address _newOwner) external {
        AssetsRegistryStorage storage $ = _getAssetsRegistryStorage();

        if ($.assets[_did].lastUpdated == 0) {
            revert AssetNotFound(_did);
        }

        if ($.assets[_did].owner != msg.sender) {
            revert NotAssetOwner(_did, msg.sender, $.assets[_did].owner);
        }

        address previousOwner = $.assets[_did].owner;
        $.assets[_did].owner = _newOwner;
        $.assets[_did].lastUpdated = block.timestamp;

        emit AssetOwnershipTransferred(_did, previousOwner, _newOwner);
    }

    /**
     * @notice Transfers the ownership of a plan to a new owner
     * @param _planId The identifier of the plan
     * @param _newOwner The address of the new owner
     */
    function transferPlanOwnership(uint256 _planId, address _newOwner) external {
        AssetsRegistryStorage storage $ = _getAssetsRegistryStorage();

        if ($.plans[_planId].lastUpdated == 0) {
            revert PlanNotFound(_planId);
        }

        if ($.plans[_planId].owner != msg.sender) {
            revert NotPlanOwner(_planId, msg.sender, $.plans[_planId].owner);
        }

        address previousOwner = $.plans[_planId].owner;
        $.plans[_planId].owner = _newOwner;
        $.plans[_planId].lastUpdated = block.timestamp;

        emit PlanOwnershipTransferred(_planId, previousOwner, _newOwner);
    }

    function areNeverminedFeesIncluded(uint256[] memory _amounts, address[] memory _receivers)
        external
        view
        returns (bool)
    {
        AssetsRegistryStorage storage $ = _getAssetsRegistryStorage();

        if ($.nvmConfig.getNetworkFee() == 0 || $.nvmConfig.getFeeReceiver() == address(0)) return true;

        uint256 totalAmount = 0;
        uint256 amountsLength = _amounts.length;
        for (uint256 i; i < amountsLength; i++) {
            unchecked {
                totalAmount += _amounts[i];
            }
        }

        if (totalAmount == 0) return true;

        bool _feeReceiverIncluded = false;
        uint256 _receiverIndex = 0;
        address feeReceiver = $.nvmConfig.getFeeReceiver();
        uint256 receiversLength = _receivers.length;

        for (uint256 i = 0; i < receiversLength; i++) {
            if (_receivers[i] == feeReceiver) {
                _feeReceiverIncluded = true;
                _receiverIndex = i;
            }
        }
        if (!_feeReceiverIncluded) return false;

        // Return if fee calculation is correct
        return _calculateFeeAmount($.nvmConfig.getNetworkFee(), totalAmount, $.nvmConfig.getFeeDenominator())
            == _amounts[_receiverIndex];
    }

    function addFeesToPaymentsDistribution(uint256[] memory _amounts, address[] memory _receivers)
        external
        view
        returns (uint256[] memory amounts, address[] memory receivers)
    {
        AssetsRegistryStorage storage $ = _getAssetsRegistryStorage();

        // If the fees are already added we don't need to do anything
        if (this.areNeverminedFeesIncluded(_amounts, _receivers)) return (_amounts, _receivers);

        uint256 totalAmount = 0;
        uint256 amountsLength = _amounts.length;
        for (uint256 i; i < amountsLength; i++) {
            unchecked {
                totalAmount += _amounts[i];
            }
        }

        // If the total amount is zero we don't need to add fees
        if (totalAmount == 0) return (_amounts, _receivers);

        uint256 feeAmount =
            _calculateFeeAmount($.nvmConfig.getNetworkFee(), totalAmount, $.nvmConfig.getFeeDenominator());

        uint256 _length = amountsLength;

        uint256[] memory amountsWithFees = new uint256[](_length + 1);
        for (uint256 i; i < _length; i++) {
            unchecked {
                amountsWithFees[i] = _amounts[i];
            }
        }
        amountsWithFees[_length] = feeAmount;

        address[] memory receiversWithFees = new address[](_length + 1);
        for (uint256 i; i < _length; i++) {
            receiversWithFees[i] = _receivers[i];
        }
        receiversWithFees[_length] = $.nvmConfig.getFeeReceiver();

        return (amountsWithFees, receiversWithFees);
    }

    function _calculateFeeAmount(uint256 _feeAmount, uint256 _totalAmount, uint256 _feeDenominator)
        internal
        pure
        returns (uint256)
    {
        return (_feeAmount * _totalAmount) / _feeDenominator;
    }

    function _getAssetsRegistryStorage() internal pure returns (AssetsRegistryStorage storage $) {
        assembly ("memory-safe") {
            $.slot := ASSETS_REGISTRY_STORAGE_LOCATION
        }
    }
}
