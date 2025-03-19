import { createPublicClient, createWalletClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { hardhat } from 'viem/chains';

// ABI for the ProxyAdmin contract's upgradeAndCall function
const proxyAdminABI = [
  {
    name: 'upgradeAndCall',
    type: 'function',
    stateMutability: 'payable',
    inputs: [
      { name: 'proxy', type: 'address' },
      { name: 'implementation', type: 'address' },
      { name: 'data', type: 'bytes' }
    ],
    outputs: []
  }
];

async function main() {
  // Get the private key from environment
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("PRIVATE_KEY environment variable not set");
  }
  
  const account = privateKeyToAccount(privateKey as `0x${string}`);
  console.log("Upgrading contracts with the account:", account.address);

  // Create clients
  const publicClient = createPublicClient({
    chain: hardhat,
    transport: http()
  });
  
  const walletClient = createWalletClient({
    chain: hardhat,
    transport: http(),
    account
  });

  // Get the ProxyAdmin contract
  const proxyAdminAddress = process.env.PROXY_ADMIN_ADDRESS;
  if (!proxyAdminAddress) {
    throw new Error("PROXY_ADMIN_ADDRESS environment variable not set");
  }

  // Get the proxy address and new implementation address
  const proxyAddress = process.env.PROXY_ADDRESS;
  const newImplementationAddress = process.env.NEW_IMPLEMENTATION_ADDRESS;
  if (!proxyAddress || !newImplementationAddress) {
    throw new Error("PROXY_ADDRESS and NEW_IMPLEMENTATION_ADDRESS environment variables must be set");
  }

  // Upgrade the proxy to the new implementation
  console.log(`Upgrading proxy at ${proxyAddress} to implementation at ${newImplementationAddress}`);
  
  try {
    // Use empty data if we just want to upgrade without calling any function
    const data = process.env.INITIALIZATION_DATA || '0x';
    
    const hash = await walletClient.writeContract({
      address: proxyAdminAddress as `0x${string}`,
      abi: proxyAdminABI,
      functionName: 'upgradeAndCall',
      args: [
        proxyAddress as `0x${string}`, 
        newImplementationAddress as `0x${string}`,
        data as `0x${string}`
      ],
      value: 0n
    });

    console.log(`Transaction sent: ${hash}`);
    console.log('Waiting for transaction confirmation...');
    
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
    console.log("Upgrade complete!");
    
    // Verify the implementation was updated
    const implementationSlot = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';
    const implementation = await publicClient.getStorageAt({
      address: proxyAddress as `0x${string}`,
      slot: implementationSlot as `0x${string}`
    });
    
    console.log(`New implementation address from storage: ${implementation}`);
  } catch (error) {
    console.error('Error upgrading contract:');
    console.error(error);
    throw error;
  }
}

// Execute the upgrade
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
