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
