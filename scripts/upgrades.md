# Contract Upgrade Process

This document outlines the step-by-step process for upgrading Nevermined contracts using the upgrade scripts.

## Prerequisites

- Access to the Safe wallet with appropriate permissions
- Access to the private key of a Safe signer
- Access to the RPC endpoint of the target network
- The new implementation contract address
- The proxy contract address to upgrade

## Environment Setup

Create a `.env.upgrades` file in the root directory with the following variables:

```bash
# Network Configuration
RPC_URL=<your-rpc-endpoint>

# Contract Addresses
PROXY_ADDRESS=<address-of-proxy-to-upgrade>
NEW_IMPLEMENTATION_ADDRESS=<address-of-new-implementation>
ACCESS_MANAGER_ADDRESS=<address-of-access-manager>

# Safe Configuration
SAFE_ADDRESS=<address-of-safe-wallet>
SAFE_SIGNER_PRIVATE_KEY=<private-key-of-safe-signer>
```

## Upgrade Process

The upgrade process consists of two main steps:

1. Initiating the upgrade (scheduling)
2. Finalizing the upgrade (execution)

### Step 1: Initiate the Upgrade

Run the following command to initiate the upgrade:

```bash
yarn upgrade:initiate
```

This will:
1. Schedule the upgrade transaction through the AccessManager
2. Calculate the required delay based on the UPGRADE_ROLE settings
3. Add a 60-second buffer to the delay for safety
4. Propose the transaction to the Safe

**Important**: You have a 60-second window to approve the transaction in the Safe interface after running this command. If you don't approve within this window, the transaction will revert due to the delay buffer.

### Step 2: Finalize the Upgrade

After the delay period has passed (which includes the 60-second buffer), run:

```bash
yarn upgrade:finalize
```

This will:
1. Check if the scheduled upgrade is ready to execute
2. Verify the current time is past the scheduled execution time
3. Propose the execution transaction to the Safe

## Important Notes

1. **Timing**: The upgrade process includes a delay period defined by the UPGRADE_ROLE settings plus a 60-second buffer. Make sure to account for this when planning upgrades.

2. **Safe Transaction Approval**: 
   - For the initiate step: You must approve the transaction within 60 seconds of running the command
   - For the finalize step: You can approve the transaction at any time after the delay period has passed

3. **Error Handling**:
   - If you miss the 60-second window for the initiate step, you'll need to run the command again
   - If you try to finalize before the delay period has passed, the script will show the remaining time and exit

4. **Verification**:
   - The script will verify the upgrade delay from the AccessManager
   - It will check if the operation is properly scheduled before allowing finalization
   - It will ensure the current time is past the scheduled execution time

## Troubleshooting

If you encounter any issues:

1. **Transaction Reverts**:
   - Check if you're within the 60-second window for the initiate step
   - Verify the Safe has the UPGRADE_ROLE
   - Ensure all environment variables are correctly set

2. **Finalization Fails**:
   - Check if the delay period has passed
   - Verify the operation was properly scheduled
   - Ensure you're using the same environment variables as the initiate step

3. **Access Denied**:
   - Verify the Safe has the UPGRADE_ROLE
   - Check if the signer's private key has permission to propose transactions to the Safe 