// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

/**
 * @title ICommon
 * @notice Common errors and events used throughout the Nevermined contracts
 */
interface ICommon {
    /***************************
     * Generic Errors
     ***************************/
    
    /// Error sending native token (i.e ETH)
    error FailedToSendNativeToken();

    /// Only an account with the right role can access this function
    /// @param sender The address of the account calling this function
    /// @param role The role required to call this function
    error InvalidRole(address sender, bytes32 role);

    /// Only the owner can call this function, but `sender` is not the owner
    /// @param sender The address of the account calling this function
    error OnlyOwner(address sender);

    /***************************
     * Config Errors
     ***************************/
    
    /// Only a valid governor address can call this function, but `sender` is not part of the governors
    /// @param sender The address of the account calling this function
    error OnlyGovernor(address sender);

    /// Fee must be between 0 and 100 percent but a `networkFee` was provided
    /// @param networkFee The network fee to configure
    error InvalidNetworkFee(uint256 networkFee);

    /// The network fee receiver can not be the zero address or an invalid address but `feeReceiver` was provided
    /// @param feeReceiver The fee receiver address to configure
    error InvalidFeeReceiver(address feeReceiver);

    /// The address provided (_address) is not valid
    /// @param _address The _address given as parameter
    error InvalidAddress(address _address);

    /// The contract version provided (_newVersion) is not higher than the latest version (_latestVersion)
    /// @param _newVersion The _newVersion given as parameter
    /// @param _latestVersion The _latestVersion of the contract already registered
    error InvalidContractVersion(uint256 _newVersion, uint256 _latestVersion);

    /// Only a valid registered template address can call this function, but `sender` is not part of the list of registered Templates
    /// @param sender The address of the account calling this function
    error OnlyTemplate(address sender);

    /// Only a valid registered template or condition address can call this function, but `sender` is not part of the list of registered Templates or Conditions
    /// @param sender The address of the account calling this function
    error OnlyTemplateOrCondition(address sender);

    /***************************
     * Agreement Errors
     ***************************/
    
    /// The `agreementId` representing the key for an Agreement is already registered
    /// @param agreementId The identifier of the agreement to store
    error AgreementAlreadyRegistered(bytes32 agreementId);

    /// The `agreementId` representing the key for an Agreement doesn't exist
    /// @param agreementId The identifier of the agreement to store
    error AgreementNotFound(bytes32 agreementId);

    /// The `conditionId` doesn't exist as part of the agreement
    /// @param conditionId The identifier of the condition associated to the agreement
    error ConditionIdNotFound(bytes32 conditionId);

    /// The preconditions for the the agreement `agreementId` are not met
    /// @param agreementId The identifier of the agreement to store
    /// @param conditionId The identifier of the condition associated to the agreement
    error ConditionPreconditionFailed(bytes32 agreementId, bytes32 conditionId);

    /***************************
     * Asset Errors
     ***************************/
    
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

    /// The `did` representing the unique identifier of an Asset doesn't exist
    /// @param did The decentralized identifier of the Asset
    error AssetNotFound(bytes32 did);

    /// The `planId` representing the unique identifier of Plan doesn't exist
    /// @param planId The unique identifier of a Plan
    error PlanNotFound(bytes32 planId);

    /// The `amounts` and `receivers` do not include the Nevermined fees
    /// @param amounts The distribution of the payment amounts
    /// @param receivers The distribution of the payment amounts receivers
    error NeverminedFeesNotIncluded(uint256[] amounts, address[] receivers);

    /***************************
     * Payment Errors
     ***************************/
    
    /// The msg.value (`msgValue`) doesn't match the amount (`amount`)
    /// @param msgValue The value sent in the transaction
    /// @param amount The amount to be transferred
    error InvalidTransactionAmount(uint256 msgValue, uint256 amount);

    /// The `priceType` given is not supported by the condition
    /// @param priceType The price type supported by the condition
    error UnsupportedPriceTypeOption(uint8 priceType);

    /// The `amounts` and `receivers` are incorrect
    /// @param amounts The distribution of the payment amounts
    /// @param receivers The distribution of the payment amounts receivers
    error IncorrectPaymentDistribution(uint256[] amounts, address[] receivers);

    /***************************
     * Lock Errors
     ***************************/
    
    /// Unlock time: `unlockTime` should be in the future
    /// @param unlockTime The time when the contract will be unlocked
    /// @param currentTime The current time
    error UnlockError(uint256 unlockTime, uint256 currentTime);

    /// It's not possible to witdraw before the unlock time
    /// @param unlockTime The time when the contract will be unlocked
    /// @param currentTime The current time
    error UnableToWithdrawYet(uint256 unlockTime, uint256 currentTime);

    /***************************
     * Config Events
     ***************************/
    
    /**
     * @notice Event that is emitted when a parameter is changed
     * @param whoChanged the address of the governor changing the parameter
     * @param parameter the hash of the name of the parameter changed
     * @param value the new value of the parameter
     */
    event NeverminedConfigChange(
        address indexed whoChanged,
        bytes32 indexed parameter,
        bytes value
    );

    /**
     * Event emitted when some permissions are granted or revoked
     * @param addressPermissions the address receving or losing permissions
     * @param permissions the role given or taken
     * @param grantPermissions if true means the permissions are granted if false means they are revoked
     */
    event ConfigPermissionsChange(
        address indexed addressPermissions,
        bytes32 indexed permissions,
        bool grantPermissions
    );

    /**
     * Event emitted when a contract is registered in the Nevermined Config contract
     * @param registeredBy the address registering the new contract
     * @param name the name of the contract registered
     * @param contractAddress the address of the contract registered
     * @param version The version of the contract registered
     */
    event ContractRegistered(
        address indexed registeredBy,
        bytes32 indexed name,
        address indexed contractAddress,
        uint256 version
    );
    
    /***************************
     * Agreement Events
     ***************************/
    
    /**
     * @notice Event that is emitted when a new Agreement is stored
     * @param agreementId the unique identifier of the agreement
     * @param creator the address of the account storing the agreement
     */
    event AgreementRegistered(
        bytes32 indexed agreementId,
        address indexed creator
    );

    /***************************
     * Asset Events
     ***************************/
    
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

    /***************************
     * Payment Events
     ***************************/
    
    /**
     * Event emitted when native token is received
     * @param from address sending the native token
     * @param value amount of native token
     */
    event ReceivedNativeToken(
        address indexed from, 
        uint256 value
    );

    /**
     * Event emitted when native token is withdrawn
     * @param from address sending the withdraw request
     * @param receiver address receiving the native token
     * @param amount amount of native token withdrawn
     */
    event WithdrawNativeToken(    
        address indexed from, 
        address indexed receiver,
        uint256 amount
    );

    /**
     * Event emitted when ERC20 token is received
     * @param erc20TokenAddress address of the ERC20 token
     * @param from address sending the token
     * @param amount amount of ERC20 token
     */
    event ReceivedERC20(
        address indexed erc20TokenAddress,
        address indexed from, 
        uint256 amount
    );

    /**
     * Event emitted when ERC20 token is withdrawn
     * @param erc20TokenAddress address of the ERC20 token
     * @param from address sending the withdraw request
     * @param receiver address receiving the ERC20 token
     * @param amount amount of ERC20 token withdrawn
     */
    event WithdrawERC20(
        address indexed erc20TokenAddress,
        address indexed from, 
        address indexed receiver,
        uint256 amount
    );

    /**
     * Event emitted on withdrawals from lock contract
     * @param amount amount withdrawn
     * @param when timestamp of withdrawal
     */
    event Withdrawal(uint256 amount, uint256 when);
}
