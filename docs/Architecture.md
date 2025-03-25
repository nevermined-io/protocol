# Nevermined Smart Contracts Architecture

This document describes the architecture of the Nevermined Smart Contracts, including the relationships between different contracts and their methods.

## Architecture Diagram

The following diagram illustrates the logical architecture of the Nevermined Smart Contracts, showing the relationships between different contracts and their methods:

![Nevermined Smart Contracts Architecture](nevermined_architecture.png)

## Core Systems

The Nevermined Smart Contracts are organized into several core systems:

### 1. Configuration and Access Control

The configuration and access control system is responsible for managing roles, fees, and contract addresses in the Nevermined protocol.

**Key Contract: NVMConfig.sol**

This contract serves as the central registry for roles, fees, and contract addresses. It implements a role-based access control system with the following key roles:
- **OWNER_ROLE**: Highest privilege role in the system, can grant/revoke governor roles
- **GOVERNOR_ROLE**: Role that can modify configuration parameters
- **TEMPLATE_ROLE**: Role assigned to agreement templates
- **CONDITION_ROLE**: Role assigned to condition contracts

Key methods:
- `initialize(address _owner, address _governor)`: Initializes the contract with owner and governor roles
- `grantGovernor(address _address)`: Grants governor role to an address
- `isTemplate(address _address)`: Checks if an address has template role
- `setNetworkFees(uint256 _networkFee, address _feeReceiver)`: Sets network fees and receiver
- `getNetworkFee()`: Returns the network fee
- `setParameter(bytes32 _paramName, bytes memory _value)`: Sets a configuration parameter

### 2. Asset Management

The asset management system handles the registration and management of digital assets and their access plans.

**Key Contract: AssetsRegistry.sol**

This contract manages asset registration and access plans, allowing asset owners to register their digital assets and define pricing and access terms.

Key methods:
- `register(bytes32 _didSeed, string memory _url, bytes32[] memory _plans)`: Registers a new asset
- `createPlan(PriceConfig memory _priceConfig, CreditsConfig memory _creditsConfig, address _nftAddress)`: Creates a new plan
- `registerAssetAndPlan(...)`: Registers both an asset and a plan in one transaction
- `getPlan(bytes32 _planId)`: Returns plan information by ID
- `areNeverminedFeesIncluded(...)`: Checks if Nevermined fees are included in payment distribution

**Interface: IAsset.sol**

Defines asset and plan data structures, including:
- **PriceType**: Enum of price types (FIXED_PRICE, FIXED_FIAT_PRICE, SMART_CONTRACT_PRICE)
- **CreditsType**: Enum for credit types (EXPIRABLE, FIXED, DYNAMIC)
- **DIDAsset**: Structure for asset information
- **PriceConfig**: Structure defining payment terms for a plan
- **CreditsConfig**: Structure defining credit properties for a plan

### 3. Agreement Management

The agreement management system handles the creation and tracking of agreements between parties.

**Key Contract: AgreementsStore.sol**

This contract stores and tracks agreements and their conditions, maintaining the state of each condition and the overall agreement status.

Key methods:
- `register(...)`: Registers a new agreement
- `updateConditionStatus(bytes32 _agreementId, bytes32 _conditionId, ConditionState _state)`: Updates condition status
- `getAgreement(bytes32 _agreementId)`: Returns agreement information by ID
- `getConditionState(bytes32 _agreementId, bytes32 _conditionId)`: Returns condition state
- `areConditionsFulfilled(...)`: Checks if conditions are fulfilled

**Key Contract: FixedPaymentTemplate.sol**

This contract implements a template for fixed payment agreements, orchestrating the creation of agreements and the fulfillment of conditions.

Key methods:
- `createAgreement(bytes32 _seed, bytes32 _did, bytes32 _planId, bytes[] memory _params)`: Creates a new agreement
- `_lockPayment(...)`: Internal method to lock payment
- `_transferPlan(...)`: Internal method to transfer plan
- `_distributePayments(...)`: Internal method to distribute payments

**Interface: IAgreement.sol**

Defines agreement structures and condition states:
- **Agreement**: Structure containing agreement details
- **ConditionState**: Enum representing status of a condition (Uninitialized, Unfulfilled, Fulfilled, Aborted)

### 4. Payment Handling

The payment handling system manages the secure handling of payments within the Nevermined protocol.

**Key Contract: PaymentsVault.sol**

This contract acts as an escrow for holding and releasing payments, supporting both native tokens and ERC20 tokens.

Key methods:
- `depositNativeToken()`: Deposits native tokens
- `withdrawNativeToken(uint256 _amount, address _receiver)`: Withdraws native tokens
- `depositERC20(address _tokenAddress, uint256 _amount, address _from)`: Deposits ERC20 tokens
- `withdrawERC20(address _tokenAddress, uint256 _amount, address _receiver)`: Withdraws ERC20 tokens

**Utility: TokenUtils.sol**

Provides utilities for token transfers and calculations, including fee calculations and token amount summation.

Key methods:
- `transferERC20()`: Transfers ERC20 tokens
- `calculateAmountSum()`: Calculates the sum of amounts in an array

**Interface: IVault.sol**

Defines the interface for vault functionality, including deposit and withdrawal operations.

### 5. Conditions

The conditions system implements various agreement conditions that must be met for agreements to proceed.

**Key Contract: LockPaymentCondition.sol**

This contract handles locking payments for agreements, ensuring that funds are secured before proceeding with the agreement.

Key methods:
- `initialize(...)`: Initializes the contract with dependencies
- `fulfill(bytes32 _conditionId, bytes32 _agreementId, bytes32 _did, bytes32 _planId, address _senderAddress)`: Fulfills the condition by locking payment

**Key Contract: TransferCreditsCondition.sol**

This contract manages the transfer of access credits to users, minting NFTs that represent access rights.

Key methods:
- `initialize(...)`: Initializes the contract with dependencies
- `fulfill(...)`: Fulfills the condition by minting credits

**Key Contract: DistributePaymentsCondition.sol**

This contract controls the distribution of payments to receivers once all required conditions are met.

Key methods:
- `initialize(...)`: Initializes the contract with dependencies
- `fulfill(...)`: Fulfills the condition by distributing payments
- `_distributeNativeTokenPayments(...)`: Internal method to distribute native tokens
- `_distributeERC20Payments(...)`: Internal method to distribute ERC20 tokens

### 6. Credits System

The credits system implements NFT-based representation of access rights.

**Key Contract: NFT1155Credits.sol**

This contract implements an ERC1155-based NFT for access rights, allowing for the minting and burning of credits.

Key methods:
- `initialize(...)`: Initializes the contract
- `mint(address _to, uint256 _id, uint256 _value, bytes memory _data)`: Mints new credits
- `burn(address _from, uint256 _id, uint256 _value)`: Burns credits

**Key Contract: NFT1155ExpirableCredits.sol**

This contract extends the NFT1155Credits contract with expiration functionality, allowing credits to expire after a specified time.

## Contract Relationships and Method Calls

### Agreement Creation Flow

1. A user interacts with the `FixedPaymentTemplate` contract to create a new agreement.
2. The `FixedPaymentTemplate.createAgreement()` method:
   - Calls `AgreementsStore.register()` to register the agreement
   - Calls `LockPaymentCondition.fulfill()` to lock payment
   - Calls `TransferCreditsCondition.fulfill()` to transfer credits
   - Calls `DistributePaymentsCondition.fulfill()` to distribute payments

### Condition Fulfillment Flow

#### Lock Payment Condition

The `LockPaymentCondition.fulfill()` method:
- Calls `NVMConfig.isTemplate()` to verify the caller is a template
- Calls `AgreementStore.agreementExists()` to check the agreement exists
- Calls `AssetsRegistry.assetExists()` to check the asset exists
- Calls `AssetsRegistry.planExists()` to check the plan exists
- Calls `AssetsRegistry.getPlan()` to get plan details
- Calls `AssetsRegistry.areNeverminedFeesIncluded()` to check fees
- Calls `TokenUtils.calculateAmountSum()` to calculate the total amount
- Calls `PaymentsVault.depositNativeToken()` or `TokenUtils.transferERC20()` + `PaymentsVault.depositERC20()` to deposit tokens
- Calls `AgreementStore.updateConditionStatus()` to update the condition status

#### Transfer Credits Condition

The `TransferCreditsCondition.fulfill()` method:
- Calls `NVMConfig.isTemplate()` to verify the caller is a template
- Calls `AssetsRegistry.assetExists()` to check the asset exists
- Calls `AssetsRegistry.planExists()` to check the plan exists
- Calls `AgreementStore.areConditionsFulfilled()` to check preconditions
- Calls `AssetsRegistry.getPlan()` to get plan details
- Calls `AgreementStore.updateConditionStatus()` to update the condition status
- Calls `NFT1155ExpirableCredits.mint()` or `NFT1155Credits.mint()` to mint credits

#### Distribute Payments Condition

The `DistributePaymentsCondition.fulfill()` method:
- Calls `NVMConfig.isTemplate()` to verify the caller is a template
- Calls `AgreementStore.getAgreement()` to get agreement details
- Calls `AssetsRegistry.assetExists()` to check the asset exists
- Calls `AssetsRegistry.planExists()` to check the plan exists
- Calls `AssetsRegistry.getPlan()` to get plan details
- Calls `AgreementStore.getConditionState()` to check condition states
- Calls `AgreementStore.updateConditionStatus()` to update the condition status
- Calls `TokenUtils.calculateAmountSum()` to calculate the total amount
- Calls `PaymentsVault.withdrawNativeToken()` or `PaymentsVault.withdrawERC20()` to withdraw tokens

## Conclusion

The Nevermined Smart Contracts implement a flexible and secure framework for digital asset exchange. The architecture is designed around a condition-based agreement system where specific conditions must be met before payments are released or access is granted. This provides a robust framework for various digital asset exchange scenarios while maintaining security and transparency.

The modular design of the contracts allows for easy extension and customization, with clear separation of concerns between different components of the system. The role-based access control system ensures that only authorized parties can perform sensitive operations, while the condition-based agreement system provides flexibility in defining the terms of agreements.
