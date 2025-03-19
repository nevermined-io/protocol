# Contract Upgrades Guide

This document explains how to upgrade the Nevermined smart contracts using the proxy pattern.

## Overview

The Nevermined contracts use the Transparent Proxy pattern from OpenZeppelin to enable upgrades without changing the contract addresses. This allows for fixing bugs, adding features, or improving the implementation without disrupting the existing ecosystem.

## Upgrade Architecture

The upgrade system consists of three main components:

1. **Proxy Contracts**: These are the contracts that users interact with. They delegate calls to the implementation contracts.
2. **Implementation Contracts**: These contain the actual logic of the system.
3. **ProxyAdmin Contract**: This manages the upgrade process and controls which implementation each proxy points to.

The following contracts in the Nevermined system are upgradeable:

- NVMConfig
- AssetsRegistry
- AgreementsStore
- PaymentsVault
- NFT1155Credits

## Upgrade Process

1. Deploy a new implementation contract
2. Use the ProxyAdmin contract to upgrade the proxy to point to the new implementation
3. If needed, initialize any new state variables in the new implementation

### Deployment with Hardhat Ignition

The repository uses Hardhat Ignition for deployments, which simplifies the process of deploying upgradeable contracts:

```typescript
// Deploy the implementation contract
const implementationContract = m.contract("ContractName", [], { from: owner });

// Get the ProxyAdmin
const { proxyAdmin } = m.useModule(ProxyAdminModule);

// Deploy the proxy with the implementation
const emptyData = "0x";
const proxyContract = m.contract(
  "TransparentUpgradeableProxy",
  [
    implementationContract,
    proxyAdmin,
    emptyData
  ],
  { from: owner }
);

// Create a contract instance that points to the proxy but uses the ABI of the implementation
const contract = m.contractAt("ContractName", proxyContract);

// Initialize the contract through the proxy
m.call(contract, "initialize", [/* initialization parameters */]);
```

## Using the Upgrade Script

The repository includes a flexible upgrade script (`scripts/upgrade-contracts.ts`) that supports both single contract upgrades and batch upgrades from a configuration file.

### Single Contract Upgrade

You can upgrade a single contract using command-line arguments or environment variables:

```bash
# Using command-line arguments
npx hardhat run scripts/upgrade-contracts.ts -- \
  --proxy 0x123... \
  --implementation 0x456... \
  --network sepolia

# Using environment variables
export MNEMONIC="your twelve word seed phrase here"
export PROXY_ADMIN_ADDRESS=0x...
export PROXY_ADDRESS=0x...
export NEW_IMPLEMENTATION_ADDRESS=0x...
export INITIALIZATION_DATA=0x  # Optional, use if you need to call a function during upgrade
export NETWORK=sepolia  # Optional, defaults to hardhat

# Run the upgrade script
yarn upgrade
```

### Batch Contract Upgrade

For upgrading multiple contracts at once, you can use a configuration file:

```bash
# Create a configuration file (upgrade-config.json)
{
  "NVMConfig": {
    "proxyAddress": "0x123...",
    "newImplementationAddress": "0x456...",
    "initializationData": "0x"  # Optional
  },
  "AssetsRegistry": {
    "proxyAddress": "0x789...",
    "newImplementationAddress": "0xabc...",
    "initializationData": "0x"  # Optional
  }
  # Add more contracts as needed
}

# Run the batch upgrade
npx hardhat run scripts/upgrade-contracts.ts -- \
  --config ./upgrade-config.json \
  --network sepolia

# Or using environment variables
export MNEMONIC="your twelve word seed phrase here"
export PROXY_ADMIN_ADDRESS=0x...
export UPGRADE_CONFIG_PATH=./upgrade-config.json
export NETWORK=sepolia

yarn upgrade
```

### Command-Line Options

The upgrade script supports the following options:

| Option | Description |
|--------|-------------|
| `--proxy` | Proxy contract address (for single contract upgrade) |
| `--implementation` | New implementation address (for single contract upgrade) |
| `--data` | Initialization data (optional, for single contract upgrade) |
| `--config` | Path to JSON config file (for multiple contract upgrade) |
| `--network` | Network to use (default: hardhat) |

### Environment Variables

Alternatively, you can use these environment variables:

| Variable | Description |
|----------|-------------|
| `PROXY_ADDRESS` | Same as `--proxy` |
| `NEW_IMPLEMENTATION_ADDRESS` | Same as `--implementation` |
| `INITIALIZATION_DATA` | Same as `--data` |
| `UPGRADE_CONFIG_PATH` | Same as `--config` |
| `NETWORK` | Same as `--network` |
| `MNEMONIC` | Mnemonic seed phrase for account (required) |
| `PROXY_ADMIN_ADDRESS` | ProxyAdmin contract address (required) |

The script will:
1. Connect to the specified network
2. Use the provided mnemonic to derive the account for signing transactions
3. Call the ProxyAdmin's upgradeAndCall function to update the proxy
4. Verify the implementation address was updated correctly

## Upgrade Considerations

When upgrading contracts, consider the following:

1. **Storage Layout**: The new implementation must maintain the same storage layout as the previous version to avoid corrupting the state. Variables can be added at the end, but existing variables cannot be removed or reordered.

2. **Initialization**: Any new state variables should be initialized in a separate function that can be called after the upgrade. This can be done by:
   - Creating a new function specifically for initializing the new variables
   - Using the `INITIALIZATION_DATA` parameter in the upgrade script to call this function during the upgrade

3. **Testing**: Always test the upgrade process on a testnet before applying it to the mainnet. This includes:
   - Deploying the current implementation and proxy
   - Using the contracts to create some state
   - Deploying the new implementation
   - Upgrading the proxy to the new implementation
   - Verifying that all state is preserved and new functionality works as expected

4. **Governance**: Upgrades should go through the proper governance process to ensure transparency and security. This typically involves:
   - Proposing the upgrade to the community
   - Allowing time for review and discussion
   - Voting on the proposal
   - Executing the upgrade if approved

## Security Best Practices

1. **Access Control**: Only authorized addresses should be able to perform upgrades. In the Nevermined system, this is controlled by the ProxyAdmin contract, which is owned by a trusted address.

2. **Timelock**: Consider implementing a timelock for upgrades to give users time to exit the system if they disagree with an upgrade.

3. **Audit**: New implementations should be audited before being deployed to ensure they don't introduce vulnerabilities.

4. **Transparent Communication**: All upgrades should be communicated to users well in advance, with clear explanations of what changes are being made and why.

## Troubleshooting

If you encounter issues during the upgrade process:

1. **Verification Failure**: If the implementation address doesn't match after the upgrade, check that you're using the correct proxy address and that the transaction was successful.

2. **Function Reverts**: If functions revert after an upgrade, check that the storage layout is compatible and that any new variables have been properly initialized.

3. **Gas Issues**: If transactions run out of gas, try increasing the gas limit. Upgrades can be gas-intensive, especially if they include initialization logic.
