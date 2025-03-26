# Ownership Transfer Scripts

This directory contains scripts for transferring ownership of the Nevermined contracts that implement the `OwnableUpgradeable` pattern.

## TransferOwnership.s.sol

This Foundry script allows transferring ownership of all contracts to a new address.

### Usage

1. Set the environment variables for all contract addresses and the new owner address:

```bash
export NVM_CONFIG_ADDRESS=0x...
export ASSETS_REGISTRY_ADDRESS=0x...
export PAYMENTS_VAULT_ADDRESS=0x...
export NFT1155_CREDITS_ADDRESS=0x...
export NFT1155_EXPIRABLE_CREDITS_ADDRESS=0x...
export AGREEMENTS_STORE_ADDRESS=0x...
export FIXED_PAYMENT_TEMPLATE_ADDRESS=0x...
export LOCK_PAYMENT_CONDITION_ADDRESS=0x...
export TRANSFER_CREDITS_CONDITION_ADDRESS=0x...
export DISTRIBUTE_PAYMENTS_CONDITION_ADDRESS=0x...
export NEW_OWNER_ADDRESS=0x...
```

2. Run the script:

```bash
forge script script/foundry/TransferOwnership.s.sol --rpc-url <RPC_URL> --broadcast
```

This will transfer ownership of all the contracts to the specified new owner address.

## Notes

- You only need to set the environment variables for the contracts you want to transfer ownership of. The script will skip any contracts with unset addresses.
- Make sure you have the necessary permissions to transfer ownership of each contract.
- The script will output the current owner of each contract before attempting to transfer ownership.
