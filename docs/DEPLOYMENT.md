# Nevermined Smart Contracts Deployment Guide

This guide provides step-by-step instructions for deploying and upgrading the Nevermined smart contracts using Foundry. The deployment scripts support both local network deployment and Base Sepolia deployment.

## Prerequisites

Before deploying the contracts, make sure you have the following:

1. Foundry installed (forge, cast, anvil)
2. Mnemonic phrase for wallet derivation
3. RPC URL for the target network (local or Base Sepolia)
4. Etherscan API key for contract verification (for Base Sepolia)

## Environment Setup

Create a `.env` file with the following variables:

```
export RPC_URL="http://localhost:8545"

export OWNER_MNEMONIC="test test test test test test test test test test test test junk"
export OWNER_INDEX=0
export OWNER_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

export GOVERNOR_MNEMONIC="test test test test test test test test test test test junk"
export GOVERNOR_INDEX=1
export GOVERNOR_ADDRESS="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

export UPGRADER_ADDRESS="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
export UPGRADE_DELAY_IN_SECONDS=86400

# Base Scan
export ETHERSCAN_API_KEY=GG46R7PA464UC7C5T4G6D13ACYVJWJFQ1U

# Optional configuration
# 1% by default (denominator is 1,000,000)
export NVM_FEE_AMOUNT=10000  
# Fee receiver address (defaults to owner address if not set)
export NVM_FEE_RECEIVER=0x731E7a35DDBB7d2b168D16824B371034f0DD0024

export DEPLOYMENT_ADDRESSES_JSON="./deployments/latest.json"
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
yarn deploy:local:install
```

3. Configure the contracts and Set network fees (requires governor role):

```bash
yarn deploy:local:config:permissions
yarn deploy:local:config:fees
```

### Understanding Mnemonic-Based Deployment

The deployment scripts use Foundry's mnemonic-based key derivation system:

1. When you run a script with `--mnemonics` and `--mnemonic-indexes` flags, Foundry automatically derives the private key from your mnemonic and specified index.

2. The scripts use `vm.startBroadcast()` without parameters, which automatically uses the derived key from the command line arguments.

3. For operations requiring different roles (owner vs governor):
   - Deploy contracts with the owner account: `--mnemonic-indexes $OWNER_INDEX`
   - Register contracts and grant permissions with the governor account: `--mnemonic-indexes $GOVERNOR_INDEX`

4. The `msg.sender` in the script will be the address derived from your mnemonic and index.


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

# Verify NFT1155ExpirableCredits
forge verify-contract <NFT1155_EXPIRABLE_CREDITS_ADDRESS> NFT1155ExpirableCredits --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY

# Verify LockPaymentCondition
forge verify-contract <LOCK_PAYMENT_CONDITION_ADDRESS> LockPaymentCondition --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY

# Verify TransferCreditsCondition
forge verify-contract <TRANSFER_CREDITS_CONDITION_ADDRESS> TransferCreditsCondition --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY

# Verify DistributePaymentsCondition
forge verify-contract <DISTRIBUTE_PAYMENTS_CONDITION_ADDRESS> DistributePaymentsCondition --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY

# Verify FixedPaymentTemplate
forge verify-contract <FIXED_PAYMENT_TEMPLATE_ADDRESS> FixedPaymentTemplate --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY

# Verify FiatPaymentTemplate
forge verify-contract <FIAT_PAYMENT_TEMPLATE_ADDRESS> FiatPaymentTemplate --chain base-sepolia --etherscan-api-key $ETHERSCAN_API_KEY
```

## Upgrading Contracts

The upgrade process for contracts is now managed via environment variables and Safe multisig. Please follow these steps:

### 1. Set Up the Upgrade Environment

Create a file named `.env.upgrades` in your project root with the following content (replace values as needed):

```sh
# RPC Endpoint
export RPC_URL=https://sepolia.base.org

# Contract Details
export PROXY_ADDRESS=0x7bcbBf5aed163064a9A8CBbe1bBb8Ec5de3581E0
export NEW_IMPLEMENTATION_ADDRESS=0xf522DAE5dEEB5D10D55fC86e187F42E99CE628aF

# Upgrades SAFE Address
export SAFE_ADDRESS=0x2020949c1B565421AC21b76e70340266c4CA9A90
export SAFE_SIGNER_PRIVATE_KEY=<redacted>

# Access Manager Address
export ACCESS_MANAGER_ADDRESS=0x286fDDB4E7ed448c52c6033c16E04Ecc5475Aa20
```

### 2. Load the Environment Variables

In your terminal, run:

```sh
source .env.upgrades
```

### 3. Initiate the Upgrade

Run:

```sh
yarn upgrade:initiate
```

- This will schedule the upgrade and propose a transaction to your Safe.
- **Check your terminal output for details.**
- Go to your Safe interface and sign the transaction.

Example output:
```
Initiating contract upgrade process...
Connected to chain ID: 84532
Retrieved upgrade delay for Safe: 10 seconds
Scheduling upgrade for proxy 0x7bcbBf5aed163064a9A8CBbe1bBb8Ec5de3581E0 to implementation 0xf522DAE5dEEB5D10D55fC86e187F42E99CE628aF
Upgrade will be executable after timestamp: 1753427357 (2025-07-25T07:09:17.000Z)
Transaction hash: 0x1d7f44192586b62a35f160504a4ac1a0408c8a2b07f42fae50aa12992583ab1c proposed to Safe... Waiting for confirmation...
Transaction proposed to Safe with hash: 0x1d7f44192586b62a35f160504a4ac1a0408c8a2b07f42fae50aa12992583ab1c
Please review and sign the transaction in your Safe interface
```

### 4. Finalize the Upgrade

After the required delay, run:

```sh
yarn upgrade:finalize
```

- This will execute the upgrade and propose another transaction to your Safe.
- **Check your terminal output for details.**
- Go to your Safe interface and sign the transaction.

Example output:
```
Finalizing contract upgrade...
Connected to chain ID: 84532
Executing scheduled contract upgrade
Proxy: 0x7bcbBf5aed163064a9A8CBbe1bBb8Ec5de3581E0
New implementation: 0xf522DAE5dEEB5D10D55fC86e187F42E99CE628aF
Transaction hash: 0x7289965e969ded2e1e60ca8956a9e96956bc1ec6ca9685706a7750cce2b66e40 proposed to Safe... Waiting for confirmation...
Upgrade execution transaction proposed to Safe with hash: 0x7289965e969ded2e1e60ca8956a9e96956bc1ec6ca9685706a7750cce2b66e40
Please review and sign the transaction in your Safe interface
```

**Note:**
- Always refer to the terminal output for the latest status and transaction hashes.
- Both steps require signing transactions in your Safe interface.

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

## Two-Step Deployment Process

The deployment is split into two main steps:

1. **Contract Deployment (Owner)**: Deploy all contract implementations using the owner account.
   ```bash
   forge script scripts/deploy/DeployAll.sol --rpc-url $RPC_URL --broadcast --mnemonics "$MNEMONIC" --mnemonic-indexes $OWNER_INDEX
   ```

2. **Contract Registration and Permissions (Governor)**: Register contracts in NVMConfig and grant necessary permissions using the governor account.
   ```bash
   forge script scripts/deploy/ManagePermissions.sol --rpc-url $RPC_URL --broadcast --mnemonics "$MNEMONIC" --mnemonic-indexes $GOVERNOR_INDEX --sig "run(address,address,address,address,address,address)" $NVM_CONFIG_ADDRESS $PAYMENTS_VAULT_ADDRESS $NFT_CREDITS_ADDRESS $LOCK_PAYMENT_CONDITION_ADDRESS $DISTRIBUTE_PAYMENTS_CONDITION_ADDRESS $TRANSFER_CREDITS_CONDITION_ADDRESS
   ```

## Troubleshooting

### Common Issues

1. **Transaction Reverted**: Check that you're using the correct mnemonic and indexes for the owner and governor accounts.

2. **Contract Initialization Failed**: Make sure you're passing the correct parameters to the initialize functions.

3. **Permission Denied**: Verify that the account calling the function has the required role. Remember that owner and governor are different roles with different permissions.

4. **Contract Verification Failed**: Ensure you're using the correct compiler version and optimization settings.

### Logs and Debugging

The deployment scripts write logs to the console and save deployment addresses to `./deployments/latest.txt`. Check these logs for any errors or warnings.

For more detailed debugging, you can use the `--verbosity` flag with forge:

```bash
forge script scripts/deploy/DeployAll.sol --rpc-url $RPC_URL --broadcast --mnemonics "$MNEMONIC" --mnemonic-indexes $OWNER_INDEX --verbosity 4
```
