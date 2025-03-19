import { createPublicClient, createWalletClient, http } from 'viem';
import { mnemonicToAccount } from 'viem/accounts';
import { 
  mainnet, 
  sepolia, 
  hardhat, 
  Chain 
} from 'viem/chains';
import * as fs from 'fs';
import * as path from 'path';

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

// Map of supported networks
const NETWORKS: Record<string, Chain> = {
  mainnet,
  sepolia,
  hardhat
};

// Define the upgradeable contracts
const UPGRADEABLE_CONTRACTS = [
  'NVMConfig',
  'AssetsRegistry',
  'AgreementsStore',
  'PaymentsVault',
  'NFT1155Credits'
];

interface UpgradeConfig {
  proxyAddress: string;
  newImplementationAddress: string;
  initializationData?: string;
}

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const parsedArgs: Record<string, string> = {};
  
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith('--') && i + 1 < args.length) {
      const key = args[i].substring(2);
      parsedArgs[key] = args[i + 1];
      i++; // Skip the next argument as it's the value
    }
  }
  
  // Set environment variables from parsed arguments
  if (parsedArgs.network) {
    process.env.NETWORK = parsedArgs.network;
  }
  
  if (parsedArgs.config) {
    process.env.UPGRADE_CONFIG_PATH = parsedArgs.config;
  }
  
  if (parsedArgs.proxy) {
    process.env.PROXY_ADDRESS = parsedArgs.proxy;
  }
  
  if (parsedArgs.implementation) {
    process.env.NEW_IMPLEMENTATION_ADDRESS = parsedArgs.implementation;
  }
  
  if (parsedArgs.data) {
    process.env.INITIALIZATION_DATA = parsedArgs.data;
  }
  
  return parsedArgs;
}

// Upgrade a single contract
async function upgradeSingleContract(
  walletClient: any,
  publicClient: any,
  proxyAdminAddress: string,
  proxyAddress: string,
  newImplementationAddress: string,
  initializationData: string = '0x'
) {
  console.log(`\n=== Upgrading contract ===`);
  console.log(`Proxy: ${proxyAddress}`);
  console.log(`New Implementation: ${newImplementationAddress}`);
  
  try {
    const hash = await walletClient.writeContract({
      address: proxyAdminAddress as `0x${string}`,
      abi: proxyAdminABI,
      functionName: 'upgradeAndCall',
      args: [
        proxyAddress as `0x${string}`, 
        newImplementationAddress as `0x${string}`,
        initializationData as `0x${string}`
      ],
      value: 0n
    });

    console.log(`Transaction sent: ${hash}`);
    console.log('Waiting for transaction confirmation...');
    
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
    
    // Verify the implementation was updated
    const implementationSlot = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';
    const implementation = await publicClient.getStorageAt({
      address: proxyAddress as `0x${string}`,
      slot: implementationSlot as `0x${string}`
    });
    
    console.log(`New implementation address from storage: ${implementation}`);
    console.log(`Upgrade complete!`);
    return true;
  } catch (error) {
    console.error(`Error upgrading contract:`);
    console.error(error);
    return false;
  }
}

// Upgrade multiple contracts from a config file
async function upgradeMultipleContracts(
  walletClient: any,
  publicClient: any,
  proxyAdminAddress: string,
  configPath: string
) {
  if (!fs.existsSync(configPath)) {
    throw new Error(`Upgrade configuration file not found at ${configPath}`);
  }

  const upgradeConfig: Record<string, UpgradeConfig> = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  
  // Validate the configuration
  for (const contractName of UPGRADEABLE_CONTRACTS) {
    if (!upgradeConfig[contractName]) {
      console.warn(`Warning: No upgrade configuration found for ${contractName}`);
    }
  }

  let successCount = 0;
  let failCount = 0;

  // Perform upgrades for each contract
  for (const [contractName, config] of Object.entries(upgradeConfig)) {
    if (!config.proxyAddress || !config.newImplementationAddress) {
      console.warn(`Skipping ${contractName}: Missing proxy or implementation address`);
      continue;
    }

    console.log(`\n=== Upgrading ${contractName} ===`);
    
    const success = await upgradeSingleContract(
      walletClient,
      publicClient,
      proxyAdminAddress,
      config.proxyAddress,
      config.newImplementationAddress,
      config.initializationData || '0x'
    );
    
    if (success) {
      successCount++;
    } else {
      failCount++;
    }
  }

  console.log(`\n=== Upgrade Summary ===`);
  console.log(`Total contracts: ${Object.keys(upgradeConfig).length}`);
  console.log(`Successful upgrades: ${successCount}`);
  console.log(`Failed upgrades: ${failCount}`);
}

// Print usage information
function printUsage() {
  console.log(`
Nevermined Contract Upgrade Tool

Usage:
  Single Contract Upgrade:
    npx hardhat run scripts/upgrade-unified.ts -- --proxy 0x123... --implementation 0x456... [--data 0x...] [--network sepolia]

  Multiple Contract Upgrade:
    npx hardhat run scripts/upgrade-unified.ts -- --config ./path/to/config.json [--network sepolia]

Options:
  --proxy           Proxy contract address (for single contract upgrade)
  --implementation  New implementation address (for single contract upgrade)
  --data            Initialization data (optional, for single contract upgrade)
  --config          Path to JSON config file (for multiple contract upgrade)
  --network         Network to use (default: hardhat)

Environment Variables (alternative to command line options):
  PROXY_ADDRESS              Same as --proxy
  NEW_IMPLEMENTATION_ADDRESS Same as --implementation
  INITIALIZATION_DATA        Same as --data
  UPGRADE_CONFIG_PATH        Same as --config
  NETWORK                    Same as --network
  MNEMONIC                   Mnemonic seed phrase for account (required)
  PROXY_ADMIN_ADDRESS        ProxyAdmin contract address (required)
  `);
}

async function main() {
  // Parse command line arguments
  const args = parseArgs();
  
  // Get the network from command line arguments or environment
  const networkName = process.env.NETWORK || 'hardhat';
  const network = NETWORKS[networkName];
  
  if (!network) {
    throw new Error(`Unsupported network: ${networkName}. Supported networks are: ${Object.keys(NETWORKS).join(', ')}`);
  }
  
  console.log(`Using network: ${networkName}`);
  
  // Get the mnemonic seed phrase from environment
  const mnemonic = process.env.MNEMONIC;
  if (!mnemonic) {
    console.error("MNEMONIC environment variable not set");
    printUsage();
    process.exit(1);
  }
  
  const account = mnemonicToAccount(mnemonic);
  console.log("Upgrading contracts with the account:", account.address);

  // Create clients
  const publicClient = createPublicClient({
    chain: network,
    transport: http()
  });
  
  const walletClient = createWalletClient({
    chain: network,
    transport: http(),
    account
  });

  // Get the ProxyAdmin contract
  const proxyAdminAddress = process.env.PROXY_ADMIN_ADDRESS;
  if (!proxyAdminAddress) {
    console.error("PROXY_ADMIN_ADDRESS environment variable not set");
    printUsage();
    process.exit(1);
  }

  // Determine if we're doing a single upgrade or multiple upgrades
  const configPath = process.env.UPGRADE_CONFIG_PATH;
  const proxyAddress = process.env.PROXY_ADDRESS;
  const newImplementationAddress = process.env.NEW_IMPLEMENTATION_ADDRESS;
  
  if (configPath) {
    // Multiple contract upgrade
    await upgradeMultipleContracts(
      walletClient,
      publicClient,
      proxyAdminAddress,
      configPath
    );
  } else if (proxyAddress && newImplementationAddress) {
    // Single contract upgrade
    const initializationData = process.env.INITIALIZATION_DATA || '0x';
    await upgradeSingleContract(
      walletClient,
      publicClient,
      proxyAdminAddress,
      proxyAddress,
      newImplementationAddress,
      initializationData
    );
  } else {
    console.error("Either --config or both --proxy and --implementation must be provided");
    printUsage();
    process.exit(1);
  }
}

// Execute the upgrade
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
