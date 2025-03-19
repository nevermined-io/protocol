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

async function main() {
  // Get the network from command line arguments
  const networkName = process.env.NETWORK || 'hardhat';
  const network = NETWORKS[networkName];
  
  if (!network) {
    throw new Error(`Unsupported network: ${networkName}. Supported networks are: ${Object.keys(NETWORKS).join(', ')}`);
  }
  
  console.log(`Using network: ${networkName}`);
  
  // Get the mnemonic seed phrase from environment
  const mnemonic = process.env.MNEMONIC;
  if (!mnemonic) {
    throw new Error("MNEMONIC environment variable not set");
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
    throw new Error("PROXY_ADMIN_ADDRESS environment variable not set");
  }

  // Load upgrade configuration from file
  const configPath = process.env.UPGRADE_CONFIG_PATH || path.join(process.cwd(), 'upgrade-config.json');
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

  // Perform upgrades for each contract
  for (const [contractName, config] of Object.entries(upgradeConfig)) {
    if (!config.proxyAddress || !config.newImplementationAddress) {
      console.warn(`Skipping ${contractName}: Missing proxy or implementation address`);
      continue;
    }

    console.log(`\n=== Upgrading ${contractName} ===`);
    console.log(`Proxy: ${config.proxyAddress}`);
    console.log(`New Implementation: ${config.newImplementationAddress}`);
    
    try {
      // Use empty data if we just want to upgrade without calling any function
      const data = config.initializationData || '0x';
      
      const hash = await walletClient.writeContract({
        address: proxyAdminAddress as `0x${string}`,
        abi: proxyAdminABI,
        functionName: 'upgradeAndCall',
        args: [
          config.proxyAddress as `0x${string}`, 
          config.newImplementationAddress as `0x${string}`,
          data as `0x${string}`
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
        address: config.proxyAddress as `0x${string}`,
        slot: implementationSlot as `0x${string}`
      });
      
      console.log(`New implementation address from storage: ${implementation}`);
      console.log(`${contractName} upgrade complete!`);
    } catch (error) {
      console.error(`Error upgrading ${contractName}:`);
      console.error(error);
      // Continue with other contracts even if one fails
    }
  }

  console.log("\nAll contract upgrades completed!");
}

// Parse command line arguments for network
function parseArgs() {
  // Check if NETWORK is already set in environment
  if (process.env.NETWORK) {
    return;
  }
  
  // Otherwise look for --network flag in command line arguments
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--network' && i + 1 < args.length) {
      process.env.NETWORK = args[i + 1];
      break;
    }
    
    if (args[i] === '--config' && i + 1 < args.length) {
      process.env.UPGRADE_CONFIG_PATH = args[i + 1];
      break;
    }
  }
}

// Parse arguments and execute the upgrade
parseArgs();
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
