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

// ABI for the NVMConfig contract
const nvmConfigABI = [
  // Role management functions
  {
    name: 'grantGovernor',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: '_address', type: 'address' }],
    outputs: []
  },
  {
    name: 'revokeGovernor',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: '_address', type: 'address' }],
    outputs: []
  },
  {
    name: 'isGovernor',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '_address', type: 'address' }],
    outputs: [{ name: '', type: 'bool' }]
  },
  {
    name: 'isOwner',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '_address', type: 'address' }],
    outputs: [{ name: '', type: 'bool' }]
  },
  {
    name: 'grantTemplate',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: '_address', type: 'address' }],
    outputs: []
  },
  {
    name: 'revokeTemplate',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: '_address', type: 'address' }],
    outputs: []
  },
  {
    name: 'isTemplate',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '_address', type: 'address' }],
    outputs: [{ name: '', type: 'bool' }]
  },
  {
    name: 'grantCondition',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: '_address', type: 'address' }],
    outputs: []
  },
  {
    name: 'revokeCondition',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: '_address', type: 'address' }],
    outputs: []
  },
  {
    name: 'isCondition',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '_address', type: 'address' }],
    outputs: [{ name: '', type: 'bool' }]
  },
  // Fee management functions
  {
    name: 'setNetworkFees',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: '_networkFee', type: 'uint256' },
      { name: '_feeReceiver', type: 'address' }
    ],
    outputs: []
  },
  {
    name: 'getNetworkFee',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }]
  },
  {
    name: 'getFeeReceiver',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }]
  },
  {
    name: 'getFeeDenominator',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }]
  },
  // Parameter management
  {
    name: 'setParameter',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: '_paramName', type: 'bytes32' },
      { name: '_value', type: 'bytes' }
    ],
    outputs: []
  },
  {
    name: 'getParameter',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '_paramName', type: 'bytes32' }],
    outputs: [
      { name: 'value', type: 'bytes' },
      { name: 'isActive', type: 'bool' },
      { name: 'lastUpdated', type: 'uint256' }
    ]
  },
  {
    name: 'disableParameter',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: '_paramName', type: 'bytes32' }],
    outputs: []
  },
  {
    name: 'parameterExists',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '_paramName', type: 'bytes32' }],
    outputs: [{ name: '', type: 'bool' }]
  }
];

// Map of supported networks
const NETWORKS: Record<string, Chain> = {
  mainnet,
  sepolia,
  hardhat,
  // Add localhost as an alias for hardhat
  localhost: hardhat
};

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const parsedArgs: Record<string, string> = {};
  const positionalArgs: string[] = [];
  let command = '';
  
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith('--') && i + 1 < args.length) {
      const key = args[i].substring(2);
      parsedArgs[key] = args[i + 1];
      i++; // Skip the next argument as it's the value
    } else if (!command && !args[i].startsWith('--')) {
      command = args[i];
    } else if (!args[i].startsWith('--')) {
      positionalArgs.push(args[i]);
    }
  }
  
  return { command, args: parsedArgs, _: positionalArgs };
}

// Print usage information
function printUsage() {
  console.log(`
Nevermined NVMConfig Admin CLI

Usage:
  npx hardhat run scripts/admin-cli.ts -- <command> [options]

Commands:
  check-permissions <address>       Check permissions for an address
  grant-governor <address>          Grant governor role to an address
  revoke-governor <address>         Revoke governor role from an address
  grant-template <address>          Grant template role to an address
  revoke-template <address>         Revoke template role from an address
  grant-condition <address>         Grant condition role to an address
  revoke-condition <address>        Revoke condition role from an address
  set-fees <fee> <receiver>         Set network fees and receiver
  get-fees                          Get current network fees and receiver
  set-parameter <name> <value>      Set a parameter
  get-parameter <name>              Get a parameter
  disable-parameter <name>          Disable a parameter

Options:
  --network <network>               Network to use (default: hardhat)
  --config-address <address>        NVMConfig contract address

Environment Variables:
  NETWORK                           Network to connect to (mainnet, sepolia, hardhat)
  MNEMONIC                          Mnemonic seed phrase for account
  NVM_CONFIG_ADDRESS                NVMConfig contract address
  `);
}

// Check permissions for an address
async function checkPermissions(
  publicClient: any,
  nvmConfigAddress: string,
  address: string
) {
  console.log(`\n=== Checking permissions for ${address} ===`);
  
  try {
    const isOwner = await publicClient.readContract({
      address: nvmConfigAddress as `0x${string}`,
      abi: nvmConfigABI,
      functionName: 'isOwner',
      args: [address as `0x${string}`]
    });
    
    const isGovernor = await publicClient.readContract({
      address: nvmConfigAddress as `0x${string}`,
      abi: nvmConfigABI,
      functionName: 'isGovernor',
      args: [address as `0x${string}`]
    });
    
    const isTemplate = await publicClient.readContract({
      address: nvmConfigAddress as `0x${string}`,
      abi: nvmConfigABI,
      functionName: 'isTemplate',
      args: [address as `0x${string}`]
    });
    
    const isCondition = await publicClient.readContract({
      address: nvmConfigAddress as `0x${string}`,
      abi: nvmConfigABI,
      functionName: 'isCondition',
      args: [address as `0x${string}`]
    });
    
    console.log(`Owner: ${isOwner}`);
    console.log(`Governor: ${isGovernor}`);
    console.log(`Template: ${isTemplate}`);
    console.log(`Condition: ${isCondition}`);
    
    return { isOwner, isGovernor, isTemplate, isCondition };
  } catch (error) {
    console.error(`Error checking permissions:`, error);
    return null;
  }
}

// Grant a role to an address
async function grantRole(
  walletClient: any,
  publicClient: any,
  nvmConfigAddress: string,
  address: string,
  role: 'governor' | 'template' | 'condition'
) {
  console.log(`\n=== Granting ${role} role to ${address} ===`);
  
  let functionName: string;
  switch (role) {
    case 'governor':
      functionName = 'grantGovernor';
      break;
    case 'template':
      functionName = 'grantTemplate';
      break;
    case 'condition':
      functionName = 'grantCondition';
      break;
    default:
      throw new Error(`Unknown role: ${role}`);
  }
  
  try {
    const hash = await walletClient.writeContract({
      address: nvmConfigAddress as `0x${string}`,
      abi: nvmConfigABI,
      functionName,
      args: [address as `0x${string}`]
    });
    
    console.log(`Transaction sent: ${hash}`);
    console.log('Waiting for transaction confirmation...');
    
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
    
    return true;
  } catch (error) {
    console.error(`Error granting ${role} role:`, error);
    return false;
  }
}

// Revoke a role from an address
async function revokeRole(
  walletClient: any,
  publicClient: any,
  nvmConfigAddress: string,
  address: string,
  role: 'governor' | 'template' | 'condition'
) {
  console.log(`\n=== Revoking ${role} role from ${address} ===`);
  
  let functionName: string;
  switch (role) {
    case 'governor':
      functionName = 'revokeGovernor';
      break;
    case 'template':
      functionName = 'revokeTemplate';
      break;
    case 'condition':
      functionName = 'revokeCondition';
      break;
    default:
      throw new Error(`Unknown role: ${role}`);
  }
  
  try {
    const hash = await walletClient.writeContract({
      address: nvmConfigAddress as `0x${string}`,
      abi: nvmConfigABI,
      functionName,
      args: [address as `0x${string}`]
    });
    
    console.log(`Transaction sent: ${hash}`);
    console.log('Waiting for transaction confirmation...');
    
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
    
    return true;
  } catch (error) {
    console.error(`Error revoking ${role} role:`, error);
    return false;
  }
}

// Set network fees
async function setNetworkFees(
  walletClient: any,
  publicClient: any,
  nvmConfigAddress: string,
  fee: bigint,
  receiver: string
) {
  console.log(`\n=== Setting network fees ===`);
  console.log(`Fee: ${fee}`);
  console.log(`Receiver: ${receiver}`);
  
  try {
    const hash = await walletClient.writeContract({
      address: nvmConfigAddress as `0x${string}`,
      abi: nvmConfigABI,
      functionName: 'setNetworkFees',
      args: [fee, receiver as `0x${string}`]
    });
    
    console.log(`Transaction sent: ${hash}`);
    console.log('Waiting for transaction confirmation...');
    
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
    
    return true;
  } catch (error) {
    console.error(`Error setting network fees:`, error);
    return false;
  }
}

// Get network fees
async function getNetworkFees(
  publicClient: any,
  nvmConfigAddress: string
) {
  console.log(`\n=== Getting network fees ===`);
  
  try {
    const fee = await publicClient.readContract({
      address: nvmConfigAddress as `0x${string}`,
      abi: nvmConfigABI,
      functionName: 'getNetworkFee'
    });
    
    const receiver = await publicClient.readContract({
      address: nvmConfigAddress as `0x${string}`,
      abi: nvmConfigABI,
      functionName: 'getFeeReceiver'
    });
    
    const denominator = await publicClient.readContract({
      address: nvmConfigAddress as `0x${string}`,
      abi: nvmConfigABI,
      functionName: 'getFeeDenominator'
    });
    
    console.log(`Network Fee: ${fee} (${Number(fee) / Number(denominator) * 100}%)`);
    console.log(`Fee Receiver: ${receiver}`);
    console.log(`Fee Denominator: ${denominator}`);
    
    return { fee, receiver, denominator };
  } catch (error) {
    console.error(`Error getting network fees:`, error);
    return null;
  }
}

// Set a parameter
async function setParameter(
  walletClient: any,
  publicClient: any,
  nvmConfigAddress: string,
  name: string,
  value: string
) {
  console.log(`\n=== Setting parameter ===`);
  console.log(`Name: ${name}`);
  console.log(`Value: ${value}`);
  
  try {
    // Convert name to bytes32
    const nameBytes32 = `0x${Buffer.from(name).toString('hex').padEnd(64, '0')}` as `0x${string}`;
    
    // Convert value to bytes
    const valueBytes = `0x${Buffer.from(value).toString('hex')}` as `0x${string}`;
    
    const hash = await walletClient.writeContract({
      address: nvmConfigAddress as `0x${string}`,
      abi: nvmConfigABI,
      functionName: 'setParameter',
      args: [nameBytes32, valueBytes]
    });
    
    console.log(`Transaction sent: ${hash}`);
    console.log('Waiting for transaction confirmation...');
    
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
    
    return true;
  } catch (error) {
    console.error(`Error setting parameter:`, error);
    return false;
  }
}

// Get a parameter
async function getParameter(
  publicClient: any,
  nvmConfigAddress: string,
  name: string
) {
  console.log(`\n=== Getting parameter ===`);
  console.log(`Name: ${name}`);
  
  try {
    // Convert name to bytes32
    const nameBytes32 = `0x${Buffer.from(name).toString('hex').padEnd(64, '0')}` as `0x${string}`;
    
    const result = await publicClient.readContract({
      address: nvmConfigAddress as `0x${string}`,
      abi: nvmConfigABI,
      functionName: 'getParameter',
      args: [nameBytes32]
    });
    
    const [valueBytes, isActive, lastUpdated] = result;
    
    // Convert bytes to string
    const value = Buffer.from(valueBytes.slice(2), 'hex').toString();
    
    console.log(`Value: ${value}`);
    console.log(`Active: ${isActive}`);
    console.log(`Last Updated: ${new Date(Number(lastUpdated) * 1000).toISOString()}`);
    
    return { value, isActive, lastUpdated };
  } catch (error) {
    console.error(`Error getting parameter:`, error);
    return null;
  }
}

// Disable a parameter
async function disableParameter(
  walletClient: any,
  publicClient: any,
  nvmConfigAddress: string,
  name: string
) {
  console.log(`\n=== Disabling parameter ===`);
  console.log(`Name: ${name}`);
  
  try {
    // Convert name to bytes32
    const nameBytes32 = `0x${Buffer.from(name).toString('hex').padEnd(64, '0')}` as `0x${string}`;
    
    const hash = await walletClient.writeContract({
      address: nvmConfigAddress as `0x${string}`,
      abi: nvmConfigABI,
      functionName: 'disableParameter',
      args: [nameBytes32]
    });
    
    console.log(`Transaction sent: ${hash}`);
    console.log('Waiting for transaction confirmation...');
    
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
    
    return true;
  } catch (error) {
    console.error(`Error disabling parameter:`, error);
    return false;
  }
}

async function main() {
  // Parse command line arguments
  const { command, args, _ } = parseArgs();
  
  if (!command) {
    printUsage();
    process.exit(1);
  }
  
  // Get the network from command line arguments or environment
  const networkName = args.network || process.env.NETWORK || 'hardhat';
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
  console.log("Using account:", account.address);
  
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
  
  // Get the NVMConfig contract address
  const nvmConfigAddress = args['config-address'] || process.env.NVM_CONFIG_ADDRESS;
  if (!nvmConfigAddress) {
    console.error("NVM_CONFIG_ADDRESS environment variable or --config-address option not set");
    printUsage();
    process.exit(1);
  }
  
  console.log(`Using NVMConfig at: ${nvmConfigAddress}`);
  
  // Execute the command
  switch (command) {
    case 'check-permissions':
      if (!_[0]) {
        console.error("Address required for check-permissions command");
        printUsage();
        process.exit(1);
      }
      await checkPermissions(publicClient, nvmConfigAddress, _[0]);
      break;
      
    case 'grant-governor':
      if (!_[0]) {
        console.error("Address required for grant-governor command");
        printUsage();
        process.exit(1);
      }
      await grantRole(walletClient, publicClient, nvmConfigAddress, _[0], 'governor');
      break;
      
    case 'revoke-governor':
      if (!_[0]) {
        console.error("Address required for revoke-governor command");
        printUsage();
        process.exit(1);
      }
      await revokeRole(walletClient, publicClient, nvmConfigAddress, _[0], 'governor');
      break;
      
    case 'grant-template':
      if (!_[0]) {
        console.error("Address required for grant-template command");
        printUsage();
        process.exit(1);
      }
      await grantRole(walletClient, publicClient, nvmConfigAddress, _[0], 'template');
      break;
      
    case 'revoke-template':
      if (!_[0]) {
        console.error("Address required for revoke-template command");
        printUsage();
        process.exit(1);
      }
      await revokeRole(walletClient, publicClient, nvmConfigAddress, _[0], 'template');
      break;
      
    case 'grant-condition':
      if (!_[0]) {
        console.error("Address required for grant-condition command");
        printUsage();
        process.exit(1);
      }
      await grantRole(walletClient, publicClient, nvmConfigAddress, _[0], 'condition');
      break;
      
    case 'revoke-condition':
      if (!_[0]) {
        console.error("Address required for revoke-condition command");
        printUsage();
        process.exit(1);
      }
      await revokeRole(walletClient, publicClient, nvmConfigAddress, _[0], 'condition');
      break;
      
    case 'set-fees':
      if (!_[0] || !_[1]) {
        console.error("Fee and receiver address required for set-fees command");
        printUsage();
        process.exit(1);
      }
      await setNetworkFees(walletClient, publicClient, nvmConfigAddress, BigInt(_[0]), _[1]);
      break;
      
    case 'get-fees':
      await getNetworkFees(publicClient, nvmConfigAddress);
      break;
      
    case 'set-parameter':
      if (!_[0] || !_[1]) {
        console.error("Name and value required for set-parameter command");
        printUsage();
        process.exit(1);
      }
      await setParameter(walletClient, publicClient, nvmConfigAddress, _[0], _[1]);
      break;
      
    case 'get-parameter':
      if (!_[0]) {
        console.error("Name required for get-parameter command");
        printUsage();
        process.exit(1);
      }
      await getParameter(publicClient, nvmConfigAddress, _[0]);
      break;
      
    case 'disable-parameter':
      if (!_[0]) {
        console.error("Name required for disable-parameter command");
        printUsage();
        process.exit(1);
      }
      await disableParameter(walletClient, publicClient, nvmConfigAddress, _[0]);
      break;
      
    default:
      console.error(`Unknown command: ${command}`);
      printUsage();
      process.exit(1);
  }
}

// Check if running through Hardhat
const isHardhatRun = process.argv[1].includes('hardhat');

// If running through Hardhat, we need to handle the arguments differently
if (isHardhatRun) {
  // The arguments will be in process.argv starting from index 3
  process.argv = [process.argv[0], process.argv[1], ...process.argv.slice(3)];
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
