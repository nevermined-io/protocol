// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.30;

import {IFeeController} from './IFeeController.sol';
import {IHook} from './IHook.sol';

/**
 * @title Asset Management Interface
 * @author Nevermined AG
 * @notice Interface defining the core asset and plan management functionality in the Nevermined Protocol
 * @dev This interface establishes the fundamental data structures, events, errors, and functions
 * required for registering and managing digital assets and their associated plans in the ecosystem
 */
interface IAsset {
    /**
     * @title PriceType
     * @notice Different types of pricing models that can be configured for a plan
     * @dev The enum value affects how payment processing and validation is performed
     */
    enum PriceType {
        /**
         * @notice Fixed amount in cryptocurrency (ERC20 or native token)
         */
        FIXED_PRICE,
        /**
         * @notice Fixed amount in fiat currency (typically USD) with off-chain settlement
         */
        FIXED_FIAT_PRICE,
        /**
         * @notice Dynamic price calculated by a smart contract at execution time
         */
        SMART_CONTRACT_PRICE
    }

    /**
     * @title CreditsType
     * @notice Different types of credit models that can be obtained when purchasing a plan
     * @dev The enum value affects how credits are managed, tracked, and consumed
     */
    enum CreditsType {
        /**
         * @notice Credits valid for a fixed duration in seconds
         */
        EXPIRABLE,
        /**
         * @notice Credits valid for a fixed number of redemptions
         */
        FIXED,
        /**
         * @notice Credits with dynamic redemption amounts
         */
        DYNAMIC
    }

    /**
     * @title RedemptionType
     * @notice Different permission models for credit redemption
     * @dev Controls who can redeem credits associated with a plan
     */
    enum RedemptionType {
        /**
         * @notice Only accounts with global CREDITS_BURNER_ROLE can redeem
         */
        ONLY_GLOBAL_ROLE,
        /**
         * @notice Only the owner of the credits can redeem
         */
        ONLY_OWNER,
        /**
         * @notice Only accounts with plan-specific redemption roles can redeem
         */
        ONLY_PLAN_ROLE
    }

    /**
     * @title DIDAsset
     * @notice Core data structure representing a registered digital asset
     * @dev Stores metadata and configuration for accessing the asset
     */
    struct DIDAsset {
        /**
         * @notice The current owner of the asset who can modify its configuration
         */
        address owner;
        /**
         * @notice Original creator of the asset (immutable after registration)
         */
        address creator;
        /**
         * @notice URL to the metadata associated with the DID
         */
        string url;
        /**
         * @notice Timestamp of when the DID was last updated
         */
        uint256 lastUpdated;
        /**
         * @notice Array of plan IDs that can be used to purchase access to the asset
         */
        uint256[] plans;
    }

    /**
     * @title PriceConfig
     * @notice Configuration for the pricing model of a plan
     * @dev Different fields are used depending on the priceType selected
     */
    struct PriceConfig {
        /**
         * @notice The type or configuration of the price
         */
        PriceType priceType;
        /**
         * @notice The address of the token for payments
         * @dev Use zero address for native token; only relevant for FIXED_PRICE or SMART_CONTRACT_PRICE
         */
        address tokenAddress;
        /**
         * @notice The payment amounts for the plan
         * @dev Only used if priceType is FIXED_PRICE or FIXED_FIAT_PRICE
         */
        uint256[] amounts;
        /**
         * @notice The payment receivers for the plan
         * @dev Only used if priceType is FIXED_PRICE
         */
        address[] receivers;
        /**
         * @notice The address of the smart contract that calculates the price
         * @dev Only used if priceType is SMART_CONTRACT_PRICE
         */
        address contractAddress;
        /**
         * @notice The address of the fee controller contract, if any
         */
        IFeeController feeController;
    }

    /**
     * @title CreditsConfig
     * @notice Configuration for the credits model of a plan
     * @dev Different fields are used depending on the creditsType selected
     */
    struct CreditsConfig {
        /**
         * @notice The type of credits granted
         */
        CreditsType creditsType;
        /**
         * @notice Controls who can redeem the credits
         */
        RedemptionType redemptionType;
        /**
         * Whether the credits burn proof signed by the user is required
         */
        bool proofRequired;
        /**
         * The duration of the credits in seconds
         * @notice only if creditsType == EXPIRABLE
         * @notice Duration in seconds that the credits remain valid
         * @dev Only used if creditsType is EXPIRABLE
         */
        uint256 durationSecs;
        /**
         * @notice Total credits granted when purchasing the plan
         */
        uint256 amount;
        /**
         * @notice Minimum credits redeemed per use
         * @dev Used for FIXED or DYNAMIC credit types
         */
        uint256 minAmount;
        /**
         * @notice Maximum credits redeemed per use
         * @dev Only used if creditsType is DYNAMIC
         */
        uint256 maxAmount;
        /**
         * @notice The address of the NFT contract that represents the plan's credits
         * @dev Only used if creditsType is FIXED
         */
        address nftAddress;
    }

    /**
     * @title Plan
     * @notice Core data structure for subscription/access plans
     * @dev Combines pricing and credits models into a complete offering
     */
    struct Plan {
        /**
         * @notice The current owner of the plan
         */
        address owner;
        /**
         * @notice The price configuration of the plan
         */
        PriceConfig price;
        /**
         * @notice The credits configuration of the plan
         */
        CreditsConfig credits;
        /**
         * @notice Timestamp of when the plan definition was last updated
         */
        uint256 lastUpdated;
    }

    /* EVENTS */

    /**
     * @notice Emitted when the fee controller allowed status is updated
     * @param feeControllerAddresses Array of fee controller addresses
     * @param creator Array of creator addresses
     * @param allowed Array of boolean values indicating if the fee controller is allowed for the creator
     */
    event FeeControllerAllowedUpdated(IFeeController[] feeControllerAddresses, address[][] creator, bool[][] allowed);

    /**
     * @notice Emitted when a new Asset is registered in the system
     * @param did The unique identifier of the asset (decentralized ID)
     * @param creator The address that registered the asset
     */
    event AssetRegistered(bytes32 indexed did, address indexed creator);

    /**
     * @notice Emitted when a new subscription/access plan is registered
     * @param planId The unique identifier of the plan
     * @param creator The address that created the plan
     */
    event PlanRegistered(uint256 indexed planId, address indexed creator);

    /**
     * @notice Emitted when an asset's ownership is transferred
     * @param did The unique identifier of the asset
     * @param previousOwner The address of the previous owner
     * @param newOwner The address of the new owner
     */
    event AssetOwnershipTransferred(bytes32 indexed did, address indexed previousOwner, address indexed newOwner);

    /**
     * @notice Emitted when a plan's ownership is transferred
     * @param planId The unique identifier of the plan
     * @param previousOwner The address of the previous owner
     * @param newOwner The address of the new owner
     */
    event PlanOwnershipTransferred(uint256 indexed planId, address indexed previousOwner, address indexed newOwner);

    /**
     * @notice Emitted when a plan is associated with an asset
     * @param did The unique identifier of the asset
     * @param planId The unique identifier of the plan
     * @param owner The address that added the plan to the asset
     */
    event PlanAddedToAsset(bytes32 indexed did, uint256 indexed planId, address indexed owner);

    /**
     * @notice Emitted when a plan is removed from an asset
     * @param did The unique identifier of the asset
     * @param planId The unique identifier of the plan
     * @param owner The address that removed the plan
     */
    event PlanRemovedFromAsset(bytes32 indexed did, uint256 indexed planId, address indexed owner);

    /**
     * @notice Emitted when all plans for an asset are replaced
     * @param did The unique identifier of the asset
     * @param owner The address that replaced the plans
     */
    event AssetPlansReplaced(bytes32 indexed did, address indexed owner);

    /**
     * @notice Emitted when a plan's fee controller is updated
     * @param planId The unique identifier of the plan
     * @param feeController The address of the new fee controller
     */
    event PlanFeeControllerUpdated(uint256 indexed planId, address indexed feeController);

    /**
     * @notice Emitted when the default fee controller is updated
     * @param feeController The address of the new default fee controller
     */
    event DefaultFeeControllerUpdated(address indexed feeController);

    /* ERRORS */

    /**
     * @notice Error thrown when a fee controller is not allowed to set the plan fee controller
     * @param creator The address of the creator
     * @param feeController The address of the fee controller
     */
    error NotAllowedToSetFeeController(address creator, IFeeController feeController);

    /**
     * @notice Error thrown when attempting to register a plan that already exists
     * @dev The planId is computed using the hash of the plan's configuration and creator
     * @param planId The identifier of the plan that already exists
     */
    error PlanAlreadyRegistered(uint256 planId);

    /**
     * @notice Error thrown when an invalid input length is provided
     */
    error InvalidInputLength();

    /**
     * @notice Error thrown when an invalid NFT contract address is provided
     * @dev The NFT address must be a valid ERC-1155 contract
     * @param nftAddress The invalid NFT contract address
     */
    error InvalidNFTAddress(address nftAddress);

    /**
     * @notice Error thrown when attempting to register an asset with a DID that already exists
     * @param did The DID that is already registered
     */
    error DIDAlreadyRegistered(bytes32 did);

    /**
     * @notice Error thrown when registering an asset without attaching any plans
     * @dev Assets must have at least one associated plan at registration
     * @param did The DID that was attempted to be registered
     */
    error NotPlansAttached(bytes32 did);

    /**
     * @notice Error thrown when attempting to access an asset that does not exist
     * @param did The DID that was not found
     */
    error AssetNotFound(bytes32 did);

    /**
     * @notice Error thrown when attempting to access a plan that does not exist
     * @param planId The plan ID that was not found
     */
    error PlanNotFound(uint256 planId);

    /**
     * @notice Error thrown when plan payment configuration does not include Nevermined protocol fees
     * @dev All plans must allocate a portion of payments to Nevermined protocol fees
     * @param amounts The distribution of payment amounts
     * @param receivers The receivers of the payments
     */
    error NeverminedFeesNotIncluded(uint256[] amounts, address[] receivers);

    /**
     * @notice Error thrown when an unsupported credits type is used
     * @param creditsType The invalid credits type
     */
    error InvalidCreditsType(CreditsType creditsType);

    /**
     * @notice Error thrown when an invalid redemption amount is specified
     * @dev The amount must be compatible with the plan's credit configuration
     * @param planId The identifier of the plan
     * @param creditsType The type of credits for the plan
     * @param amount The invalid redemption amount
     */
    error InvalidRedemptionAmount(uint256 planId, CreditsType creditsType, uint256 amount);

    /**
     * @notice Error thrown when a non-owner attempts to modify an asset
     * @param did The identifier of the asset
     * @param caller The address of the caller
     * @param owner The current owner of the asset
     */
    error NotAssetOwner(bytes32 did, address caller, address owner);

    /**
     * @notice Error thrown when a non-owner attempts to modify a plan
     * @param planId The identifier of the plan
     * @param caller The address of the caller
     * @param owner The current owner of the plan
     */
    error NotPlanOwner(uint256 planId, address caller, address owner);

    /**
     * @notice Error thrown when attempting to modify a plan that is not associated with an asset
     * @param did The DID of the asset
     * @param planId The ID of the plan that is not associated with the asset
     */
    error PlanNotInAsset(bytes32 did, uint256 planId);

    /**
     * @notice Error thrown when an invalid URL is provided
     * @param url The invalid URL
     */
    error InvalidURL(string url);

    /**
     * @notice Error thrown when multiple fee receivers are included in a payment distribution
     * @dev Only one fee receiver is allowed in a payment distribution
     */
    error MultipleFeeReceiversIncluded();

    /**
     * @notice Error thrown when the payment distribution amounts and receivers are not compatible
     */
    error PriceConfigInvalidAmountsOrReceivers();

    /* FUNCTIONS */

    /**
     * @notice Retrieves the full details of an asset
     * @param _did The unique identifier of the asset
     * @return The DIDAsset struct containing the asset's details
     */
    function getAsset(bytes32 _did) external view returns (DIDAsset memory);

    /**
     * @notice Checks if an asset exists in the registry
     * @param _did The unique identifier of the asset
     * @return Boolean indicating whether the asset exists
     */
    function assetExists(bytes32 _did) external view returns (bool);

    /**
     * @notice Retrieves the full details of a plan
     * @param _planId The unique identifier of the plan
     * @return The Plan struct containing the plan's details
     */
    function getPlan(uint256 _planId) external view returns (Plan memory);

    /**
     * @notice Checks if a plan exists in the registry
     * @param _planId The unique identifier of the plan
     * @return Boolean indicating whether the plan exists
     */
    function planExists(uint256 _planId) external view returns (bool);

    /**
     * @notice Checks if Nevermined protocol fees are correctly included in a payment distribution
     * @param _planId The ID of the plan to check
     * @return Boolean indicating whether Nevermined fees are correctly included
     */
    function areNeverminedFeesIncluded(uint256 _planId) external view returns (bool);

    /**
     * @notice Associates a plan with an asset
     * @dev Only the owner of the asset can call this function
     * @param _did The unique identifier of the asset
     * @param _planId The unique identifier of the plan to add
     */
    function addPlanToAsset(bytes32 _did, uint256 _planId) external;

    /**
     * @notice Removes a plan from an asset
     * @dev Only the owner of the asset can call this function
     * @param _did The unique identifier of the asset
     * @param _planId The unique identifier of the plan to remove
     */
    function removePlanFromAsset(bytes32 _did, uint256 _planId) external;

    /**
     * @notice Replaces all plans associated with an asset
     * @dev Only the owner of the asset can call this function
     * @param _did The unique identifier of the asset
     * @param _plans Array of plan identifiers to associate with the asset
     */
    function replacePlansForAsset(bytes32 _did, uint256[] memory _plans) external;

    /**
     * @notice Transfers the ownership of an asset to a new owner
     * @dev Only the current owner of the asset can call this function
     * @param _did The unique identifier of the asset
     * @param _newOwner The address of the new owner
     */
    function transferAssetOwnership(bytes32 _did, address _newOwner) external;

    /**
     * @notice Transfers the ownership of a plan to a new owner
     * @dev Only the current owner of the plan can call this function
     * @param _planId The unique identifier of the plan
     * @param _newOwner The address of the new owner
     */
    function transferPlanOwnership(uint256 _planId, address _newOwner) external;

    /**
     * @notice Gets the hooks associated with a plan
     * @param _planId The ID of the plan
     * @return Array of hook contracts
     */
    function getPlanHooks(uint256 _planId) external view returns (IHook[] memory);
}
