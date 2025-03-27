# Ownership Transfer Scripts

This directory contains scripts for transferring ownership of the Nevermined contracts that implement the `OwnableUpgradeable` pattern.

## transfer-ownership.ts

This script allows transferring ownership of all contracts to a new address.

### Usage as a Hardhat Task

The recommended way to use this script is as a Hardhat task:

```bash
npx hardhat transfer-ownership --new-owner 0xYourNewOwnerAddress --network <network>
```

### Usage as a Script

Alternatively, you can run it as a regular script by setting the environment variable:

```bash
export NEW_OWNER_ADDRESS=0xYourNewOwnerAddress
npx hardhat run scripts/transfer-ownership.ts --network <network>
```

### Contracts Affected

The script will transfer ownership of the following contracts:

- NVMConfig
- AssetsRegistry
- PaymentsVault
- NFT1155Credits
- NFT1155ExpirableCredits
- AgreementsStore
- FixedPaymentTemplate
- LockPaymentCondition
- TransferCreditsCondition
- DistributePaymentsCondition

### Contract Addresses

You need to provide the addresses of the deployed contracts as environment variables:

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
```

If any of these environment variables are not set, the script will skip the corresponding contract.
