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

export OWNER_MNEMONIC="test test test test test test test test test test test junk"
export OWNER_INDEX=0
export OWNER_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

export GOVERNOR_MNEMONIC="test test test test test test test test test test test junk"
export GOVERNOR_INDEX=1
export GOVERNOR_ADDRESS="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

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
mkdir -p deployments
forge script scripts/deploy/DeployAll.sol --extra-output-files abi --rpc-url $RPC_URL --broadcast --mnemonics "$OWNER_MNEMONIC" --mnemonic-indexes $OWNER_INDEX --sender $OWNER_ADDRESS --verify

```

3. Configure the contracts and Set network fees (requires governor role):

```bash
# Set network fees using the governor account
forge script scripts/deploy/ConfigureAll.sol --rpc-url $RPC_URL --broadcast --mnemonics "$GOVERNOR_MNEMONIC" --mnemonic-indexes $GOVERNOR_INDEX --sender $GOVERNOR_ADDRESS

```

### Understanding Mnemonic-Based Deployment

The deployment scripts use Foundry's mnemonic-based key derivation system:

1. When you run a script with `--mnemonics` and `--mnemonic-indexes` flags, Foundry automatically derives the private key from your mnemonic and specified index.

2. The scripts use `vm.startBroadcast()` without parameters, which automatically uses the derived key from the command line arguments.

3. For operations requiring different roles (owner vs governor):
   - Deploy contracts with the owner account: `--mnemonic-indexes $OWNER_INDEX`
   - Register contracts and grant permissions with the governor account: `--mnemonic-indexes $GOVERNOR_INDEX`

4. The `msg.sender` in the script will be the address derived from your mnemonic and index.

5. **Important**: Some operations like setting network fees require the governor role. These must be executed in separate steps using the governor's mnemonic index.

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
forge create contracts/AssetsRegistry.sol:AssetsRegistry --rpc-url $RPC_URL --mnemonics "$MNEMONIC" --mnemonic-indexes $OWNER_INDEX
```

2. Register the new implementation in NVMConfig (must be done by the governor):

```bash
# Get the contract name hash
export CONTRACT_NAME=$(cast keccak "AssetsRegistry")

# Register the new implementation
forge script scripts/upgrade/UpgradeContract.sol --rpc-url $RPC_URL --broadcast --mnemonics "$MNEMONIC" --mnemonic-indexes $GOVERNOR_INDEX --sig "run(address,bytes32,address)" $NVM_CONFIG_ADDRESS $CONTRACT_NAME $NEW_IMPLEMENTATION_ADDRESS
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
