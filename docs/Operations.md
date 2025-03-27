# Smart Contracts Operations

## Ownership Transfer

The contracts now implement OpenZeppelin's `OwnableUpgradeable` pattern. This allows transferring ownership of the contracts to a new address.

### Using Foundry

The `TransferOwnership.s.sol` Foundry script allows transferring ownership of all contracts to a new address.

Steps:

1. Set the environment variables for all contract addresses and the new owner address:

```bash
export RPC_URL="http://localhost:8545"
export OWNER_MNEMONIC="test test test test test test test test test test test junk"
export OWNER_INDEX=0
export OWNER_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
export NEW_OWNER_ADDRESS="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
export DEPLOYMENT_ADDRESSES_JSON=./deployments/addresses-<network>.json

```

2. Run the script:

```bash
forge script scripts/ops/TransferOwnership.s.sol --rpc-url $RPC_URL --broadcast --mnemonics "$OWNER_MNEMONIC" --mnemonic-indexes $OWNER_INDEX --sender $OWNER_ADDRESS
```

This will transfer ownership of all the contracts to the specified new owner address.

#### Notes

- You only need to set the environment variables for the contracts you want to transfer ownership of. The script will skip any contracts with unset addresses.
- Make sure you have the necessary permissions to transfer ownership of each contract.
- The script will output the current owner of each contract before attempting to transfer ownership.

### Via script

To transfer ownership of all contracts to a new address, you can use the provided script:

```bash
# Set the new owner address
export NEW_OWNER_ADDRESS=0xNewOwnerAddressHere
    
# Run the transfer script
npx hardhat run scripts/transfer-ownership.ts --network <network>
```

This will transfer ownership of all contracts to the provided address.

## Contract Verification

After deploying contracts, you need to verify them on the blockchain explorer to make their source code publicly available. This enables users to interact with the contracts through the explorer interface and verify the contract's functionality.

### Using the Verification Script

The `verify-contracts.ts` script automates the verification process for all deployed contracts. It checks if contracts are already verified before attempting verification and includes retry logic for failed verifications.

Steps:

1. Set the required environment variables:

```bash
# Path to the JSON file containing contract names and addresses
export DEPLOYMENT_ADDRESSES_JSON=./deployments/addresses-<network>.json

# Etherscan API key for verification
export ETHERSCAN_API_KEY=your_etherscan_api_key

# Chain ID of the network where contracts are deployed
# Common chain IDs:
# - 1: Ethereum Mainnet
# - 11155111: Sepolia
# - 8453: Base
# - 84532: Base Sepolia
export CHAIN_ID=84532
```

2. Run the verification script:

```bash
npx ts-node scripts/verify-contracts.ts
```

The script will:
- Check if each contract is already verified
- Skip already verified contracts
- Attempt to verify unverified contracts with automatic retries
- Provide a summary of verification results

#### Example JSON Format

The `DEPLOYMENT_ADDRESSES_JSON` file should contain a mapping of contract names to their addresses:

```json
{
  "NVMConfig": "0xC9a43158891282A2B1475592D5719c001986Aaec",
  "AssetsRegistry": "0x28403219dD702291B296cAdc9dFD920FEe40727a",
  "AgreementsStore": "0x8f86403A4DE0BB5791fa46B8e795C547942fE4Cf"
}
```

#### Notes

- The script automatically handles verification for all contracts in the JSON file
- It includes retry logic with exponential backoff for failed verifications
- Verification status is checked before attempting verification to avoid unnecessary operations
- A non-zero exit code is returned if any verifications fail
