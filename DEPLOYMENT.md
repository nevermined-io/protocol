# Nevermined Smart Contracts Deployment Guide

This guide provides step-by-step instructions for deploying and upgrading the Nevermined smart contracts using Foundry. The deployment scripts support both local network deployment and Base Sepolia deployment.

## Prerequisites

Before deploying the contracts, make sure you have the following:

1. Foundry installed (forge, cast, anvil)
2. Private keys for the owner and governor accounts
3. RPC URL for the target network (local or Base Sepolia)
4. Etherscan API key for contract verification (for Base Sepolia)

## Environment Setup

Create a `.env` file with the following variables:

```
# Private keys (without 0x prefix)
OWNER_PRIVATE_KEY=your_owner_private_key
GOVERNOR_PRIVATE_KEY=your_governor_private_key

# Network configuration
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
ETHERSCAN_API_KEY=your_etherscan_api_key

# Optional configuration
NVM_FEE_AMOUNT=10000  # 1% by default (denominator is 1,000,000)
NVM_FEE_RECEIVER=0x...  # Fee receiver address (defaults to owner address if not set)
```

Load the environment variables:

```bash
source .env
```

## Deployment

### Local Network Deployment

1. Start a local Ethereum node:

```bash
anvil
```

2. Deploy all contracts:

```bash
mkdir -p deployments
forge script scripts/deploy/DeployAll.sol --rpc-url http://localhost:8545 --broadcast --private-key $OWNER_PRIVATE_KEY
```

### Base Sepolia Deployment

Deploy all contracts to Base Sepolia:

```bash
mkdir -p deployments
forge script scripts/deploy/DeployAll.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --private-key $OWNER_PRIVATE_KEY
```

## Contract Verification

After deploying to Base Sepolia, you can verify the contracts on Basescan:

```bash
# Verify NVMConfig
forge verify-contract <NVM_CONFIG_ADDRESS> NVMConfig --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY

# Verify AssetsRegistry
forge verify-contract <ASSETS_REGISTRY_ADDRESS> AssetsRegistry --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY

# Verify AgreementsStore
forge verify-contract <AGREEMENTS_STORE_ADDRESS> AgreementsStore --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY

# Verify PaymentsVault
forge verify-contract <PAYMENTS_VAULT_ADDRESS> PaymentsVault --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY

# Verify NFT1155Credits
forge verify-contract <NFT1155_CREDITS_ADDRESS> NFT1155Credits --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY

# Verify LockPaymentCondition
forge verify-contract <LOCK_PAYMENT_CONDITION_ADDRESS> LockPaymentCondition --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY

# Verify TransferCreditsCondition
forge verify-contract <TRANSFER_CREDITS_CONDITION_ADDRESS> TransferCreditsCondition --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY

# Verify DistributePaymentsCondition
forge verify-contract <DISTRIBUTE_PAYMENTS_CONDITION_ADDRESS> DistributePaymentsCondition --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY

# Verify FixedPaymentTemplate
forge verify-contract <FIXED_PAYMENT_TEMPLATE_ADDRESS> FixedPaymentTemplate --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY
```

## Contract Upgrades

The Nevermined contracts follow an upgradeable pattern where new implementations are registered in the NVMConfig contract. To upgrade a contract:

1. Deploy the new implementation:

```bash
# Example for deploying a new AssetsRegistry implementation
forge create contracts/AssetsRegistry.sol:AssetsRegistry --rpc-url $RPC_URL --private-key $OWNER_PRIVATE_KEY
```

2. Register the new implementation in NVMConfig:

```bash
# Get the contract name hash
export CONTRACT_NAME=$(cast keccak "AssetsRegistry")

# Register the new implementation
forge script scripts/upgrade/UpgradeContract.sol --rpc-url $RPC_URL --broadcast --private-key $GOVERNOR_PRIVATE_KEY --sig "run(address,bytes32,address)" $NVM_CONFIG_ADDRESS $CONTRACT_NAME $NEW_IMPLEMENTATION_ADDRESS
```

## Deployment Verification Checklist

After deployment, verify that:

1. All contracts are deployed successfully
2. NVMConfig is initialized with the correct owner and governor
3. All contracts are registered in NVMConfig with the correct version
4. All necessary roles and permissions are granted:
   - LockPaymentCondition has DEPOSITOR_ROLE for PaymentsVault
   - DistributePaymentsCondition has WITHDRAW_ROLE for PaymentsVault
   - TransferCreditsCondition has CREDITS_MINTER_ROLE for NFT1155Credits
   - All conditions have the CONTRACT_CONDITION_ROLE in NVMConfig
   - FixedPaymentTemplate has the CONTRACT_TEMPLATE_ROLE in NVMConfig
5. Network fees are set correctly in NVMConfig

## Deployment Order

The deployment scripts follow this order:

1. NVMConfig
2. Libraries (TokenUtils)
3. Core Contracts (AssetsRegistry, AgreementsStore, PaymentsVault)
4. NFT Contracts (NFT1155Credits)
5. Conditions (LockPaymentCondition, TransferCreditsCondition, DistributePaymentsCondition)
6. Templates (FixedPaymentTemplate)
7. Permission Management

This order ensures that all dependencies are properly set up before they are needed.

## Troubleshooting

### Common Issues

1. **Transaction Reverted**: Check that you're using the correct private keys for the owner and governor accounts.

2. **Contract Initialization Failed**: Make sure you're passing the correct parameters to the initialize functions.

3. **Permission Denied**: Verify that the account calling the function has the required role.

4. **Contract Verification Failed**: Ensure you're using the correct compiler version and optimization settings.

### Logs and Debugging

The deployment scripts write logs to the console and save deployment addresses to `./deployments/latest.txt`. Check these logs for any errors or warnings.

For more detailed debugging, you can use the `--verbosity` flag with forge:

```bash
forge script scripts/deploy/DeployAll.sol --rpc-url $RPC_URL --broadcast --private-key $OWNER_PRIVATE_KEY --verbosity 4
```
