// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

interface IAsset {
    /// Different types of prices that can be configured for a plan
    /// @notice 0 - FIXED_PRICE, 1 - FIXED_FIAT_PRICE, 2 - SMART_CONTRACT_PRICE
    /// If FIXED_PRICE it means the plan can be paid in crypto by a fixed amount of a ERC20 or Native token
    /// If FIXED_FIAT_PRICE it means the plan can be paid in fiat by a fixed amount (typically USD)
    /// If SMART_CONTRACT_PRICE it means the plan can be paid in crypto and the amount to be paid is calculated by a smart contract
    enum PriceType {
        FIXED_PRICE,
        FIXED_FIAT_PRICE,
        SMART_CONTRACT_PRICE
    }

    /// Different types of credits that can be obtained when purchasing a plan
    /// @notice 0 - EXPIRABLE, 1 - FIXED, 2 - DYNAMIC
    /// If EXPIRABLE it means the credits can be used for a fixed amount of time (calculated in seconds)
    /// If FIXED it means the credits can be used for a fixed amount of times
    /// If DYNAMIC it means the credits can be used but the redemption amount is dynamic
    enum CreditsType {
        EXPIRABLE,
        FIXED,
        DYNAMIC
    }

    /// Different types of redemptions criterias that can be used when redeeming credits
    /// @notice 0 - ONLY_GLOBAL_ROLE, 1 - ONLY_OWNER, 2 - ROLE_AND_OWNER
    /// If ONLY_GLOBAL_ROLE it means the credits can be redeemed only by an account with the `CREDITS_BURNER_ROLE`
    /// If ONLY_OWNER it means the credits can be redeemed only by the owner of the Plan
    /// If ONLY_PLAN_ROLE it means the credits can be redeemed by an account with specifics grants for the plan
    enum RedemptionType {
        ONLY_GLOBAL_ROLE,
        ONLY_OWNER,
        ONLY_PLAN_ROLE
    }

    struct DIDAsset {
        // The owner of the asset
        address owner;
        // Asset original creator, this can't be modified after the asset is registered
        address creator;
        // URL to the metadata associated to the DID
        string url;
        // When was the DID last updated
        uint256 lastUpdated;
        // Array of plans that can be used to purchase access to the asset
        uint256[] plans;
    }

    /// Definition of the price configuration for a plan
    struct PriceConfig {
        /**
         * The type or configuration of the price
         * @notice 0 - fixed price. 1 - fiat price. 2 - smart contract price
         */
        PriceType priceType;
        /**
         * The address of the token (ERC20 or Native if zero address) for paying the plan
         * @notice only if priceType == FIXED_PRICE or SMART_CONTRACT_PRICE
         */
        address tokenAddress;
        /**
         * The amounts to be paid for the plan
         * @notice only if priceType == FIXED_PRICE or FIXED_FIAT_PRICE
         */
        uint256[] amounts;
        /**
         * The receivers of the payments of the plan
         * @notice only if priceType == FIXED_PRICE
         */
        address[] receivers;
        /**
         * The address of the smart contract that calculates the price
         * @notice only if priceType == SMART_CONTRACT_PRICE
         */
        address contractAddress; // only if priceType == 2
    }

    /// Definition of the credits configuration for a plan
    struct CreditsConfig {
        /**
         * The type of configuration of the credits type
         */
        CreditsType creditsType;
        /**
         * How the credits can be redeemed
         */
        RedemptionType redemptionType;
        /**
         * The duration of the credits in seconds
         * @notice only if creditsType == EXPIRABLE
         */
        uint256 durationSecs;
        /**
         * The amount of credits that are granted when purchasing the plan
         */
        uint256 amount;
        /**
         * The minimum number of credits redeemed when using the plan
         * @notice only if creditsType == FIXED or DYNAMIC
         */
        uint256 minAmount;
        /**
         * The maximum number of credits redeemed when using the plan
         * @notice only if creditsType == DYNAMIC
         */
        uint256 maxAmount;
    }

    /// Definition of a plan
    struct Plan {
        // The owner of the Plan
        address owner;
        // The price configuration of the plan
        PriceConfig price;
        // The credits configuration of the plan
        CreditsConfig credits;
        // The address of the NFT contract that represents the plan
        address nftAddress;
        // The timestamp of the last time the plan definition was updated
        uint256 lastUpdated;
    }

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
    event PlanRegistered(uint256 indexed planId, address indexed creator);

    /**
     * @notice Event that is emitted when an asset ownership is transferred
     * @param did the unique identifier of the asset
     * @param previousOwner the address of the previous owner
     * @param newOwner the address of the new owner
     */
    event AssetOwnershipTransferred(bytes32 indexed did, address indexed previousOwner, address indexed newOwner);

    /**
     * @notice Event that is emitted when a plan ownership is transferred
     * @param planId the unique identifier of the plan
     * @param previousOwner the address of the previous owner
     * @param newOwner the address of the new owner
     */
    event PlanOwnershipTransferred(uint256 indexed planId, address indexed previousOwner, address indexed newOwner);

    /// A plan with the same `plainId` is already registered and can not be registered again.abi
    /// The `planId` is computed using the hash of the `PriceConfig`, `CreditsConfig`, `nftAddress` and the creator of the plan
    /// @param planId The identifier of the plan
    error PlanAlreadyRegistered(uint256 planId);

    /// The DID `did` representing the key for an Asset is already registered
    /// @param did The identifier of the asset to register
    error DIDAlreadyRegistered(bytes32 did);

    /// When registering the asset, the plans array is empty
    /// @param did The identifier to register
    error NotPlansAttached(bytes32 did);

    /// The `did` representing the unique identifier of an Asset doesn't exist
    /// @param did The decentralized identifier of the Asset
    error AssetNotFound(bytes32 did);

    /// The `planId` representing the unique identifier of Plan doesn't exist
    /// @param planId The unique identifier of a Plan
    error PlanNotFound(uint256 planId);

    /// The `amounts` and `receivers` do not include the Nevermined fees
    /// @param amounts The distribution of the payment amounts
    /// @param receivers The distribution of the payment amounts receivers
    error NeverminedFeesNotIncluded(uint256[] amounts, address[] receivers);

    /// The `creditsType` given as parameter is not supported
    /// @param creditsType The type of credits
    error InvalidCreditsType(CreditsType creditsType);

    /// The `amount` of credits to redeem is not valid
    /// @param planId The identifier of the plan
    /// @param creditsType The type of credits
    /// @param amount The amount of credits to redeem
    error InvalidRedemptionAmount(uint256 planId, CreditsType creditsType, uint256 amount);

    /// The caller is not the owner of the asset
    /// @param did The identifier of the asset
    /// @param caller The address of the caller
    /// @param owner The address of the owner
    error NotAssetOwner(bytes32 did, address caller, address owner);

    /// The caller is not the owner of the plan
    /// @param planId The identifier of the plan
    /// @param caller The address of the caller
    /// @param owner The address of the owner
    error NotPlanOwner(uint256 planId, address caller, address owner);

    function getAsset(bytes32 _did) external view returns (DIDAsset memory);

    function assetExists(bytes32 _did) external view returns (bool);

    function getPlan(uint256 _planId) external view returns (Plan memory);

    function planExists(uint256 _planId) external view returns (bool);

    function areNeverminedFeesIncluded(uint256[] memory _amounts, address[] memory _receivers)
        external
        view
        returns (bool);
        
    /**
     * @notice Transfers the ownership of an asset to a new owner
     * @param _did The identifier of the asset
     * @param _newOwner The address of the new owner
     */
    function transferAssetOwnership(bytes32 _did, address _newOwner) external;
    
    /**
     * @notice Transfers the ownership of a plan to a new owner
     * @param _planId The identifier of the plan
     * @param _newOwner The address of the new owner
     */
    function transferPlanOwnership(uint256 _planId, address _newOwner) external;
}
