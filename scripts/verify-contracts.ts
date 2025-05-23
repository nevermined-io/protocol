import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Verify Smart Contracts using forge verify-contract command
 * 
 * Required environment variables:
 * - DEPLOYMENT_ADDRESSES_JSON: Path to the JSON file with contract addresses
 * - ETHERSCAN_API_KEY: API key for Etherscan verification
 * - CHAIN_ID: Chain ID for the target network
 */

const CHAIN_ID_TO_NETWORK: Record<string, string> = {
  '1': 'mainnet',
  '5': 'goerli',
  '11155111': 'sepolia',
  '8453': 'base',
  '84531': 'base-goerli',
  '84532': 'base-sepolia'
};

let CONTRACT_LIBRARIES = {
  'TokenUtils': { 'address': '0x0', 'path': 'contracts/utils/TokenUtils.sol' },
}
let librariesOptions = ''

enum VerificationStatus {
  AlreadyVerified = 'AlreadyVerified',
  Success = 'Success',
  Failure = 'Failure'
}
const MAX_RETRY_ATTEMPTS = 3;
const BASE_RETRY_DELAY = 5000;



function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function verifyContract(
  contractName: string, 
  contractAddress: string, 
  networkName: string, 
  etherscanApiKey: string,
  libraries: string
): Promise<VerificationStatus> {
  for (let attempt = 1; attempt <= MAX_RETRY_ATTEMPTS; attempt++) {
    try {
      console.log(`Attempt ${attempt}/${MAX_RETRY_ATTEMPTS} to verify ${contractName} at ${contractAddress}`);
      
      const command = `forge verify-contract ${contractAddress} ${contractName} --chain ${networkName} --etherscan-api-key "${etherscanApiKey}" ${libraries} `;
      console.log(`Executing: ${command.replace(etherscanApiKey, '***')}`);
      
      const output = execSync(command, { encoding: 'utf8' });
      console.log(output);
      
      if (output.includes('Successfully verified')) {
        console.log(`✅ Successfully verified ${contractName}`);
        return VerificationStatus.Success;
      } else if (output.includes('already verified')) {
        console.log(`✅ Already verified ${contractName}`);
        return VerificationStatus.AlreadyVerified;      
      }
      
      console.log(`Verification output did not confirm success, will retry...`);
    } catch (error: any) {
      
      console.error(`❌ Attempt ${attempt}/${MAX_RETRY_ATTEMPTS} failed to verify ${contractName}:`);
      console.error(error.message || error);
      
      if (attempt < MAX_RETRY_ATTEMPTS) {
        const delayMs = BASE_RETRY_DELAY * Math.pow(2, attempt - 1);
        console.log(`Waiting ${delayMs/1000} seconds before retry...`);
        await sleep(delayMs);
      } else {
        console.error(`❌ All ${MAX_RETRY_ATTEMPTS} attempts to verify ${contractName} failed`);
        return VerificationStatus.Failure;
      }
    }
  }
  
  return VerificationStatus.Failure;
}

async function verifyContracts() {
  try {
    const deploymentAddressesPath = process.env.DEPLOYMENT_ADDRESSES_JSON;
    const etherscanApiKey = process.env.ETHERSCAN_API_KEY;
    const chainId = process.env.CHAIN_ID;

    if (!deploymentAddressesPath) {
      throw new Error('DEPLOYMENT_ADDRESSES_JSON environment variable is not set');
    }

    if (!etherscanApiKey) {
      throw new Error('ETHERSCAN_API_KEY environment variable is not set');
    }

    if (!chainId) {
      throw new Error('CHAIN_ID environment variable is not set');
    }

    const networkName = CHAIN_ID_TO_NETWORK[chainId];
    if (!networkName) {
      throw new Error(`Unsupported chain ID: ${chainId}. Supported chain IDs: ${Object.keys(CHAIN_ID_TO_NETWORK).join(', ')}`);
    }

    console.log(`Verifying contracts on network: ${networkName} (Chain ID: ${chainId})`);

    if (!fs.existsSync(deploymentAddressesPath)) {
      throw new Error(`Deployment addresses file not found at ${deploymentAddressesPath}`);
    }

    let deploymentAddresses: Record<string, string>;
    try {
      const fileContent = fs.readFileSync(deploymentAddressesPath, 'utf8');
      deploymentAddresses = JSON.parse(fileContent);
    } catch (error) {
      throw new Error(`Error reading or parsing deployment addresses file: ${error}`);
    }

    const contractNames = Object.keys(deploymentAddresses);
    console.log(`Found ${contractNames.length} contracts to verify`);

    const librariesNames = Object.keys(CONTRACT_LIBRARIES);
    
    librariesOptions = ''
    librariesNames.forEach((libraryName) => {
      const libraryAddress: string = deploymentAddresses[libraryName as keyof typeof CONTRACT_LIBRARIES];
      const libraryPath: string = CONTRACT_LIBRARIES[libraryName as keyof typeof CONTRACT_LIBRARIES]['path'];
      CONTRACT_LIBRARIES[libraryName as keyof typeof CONTRACT_LIBRARIES]['address'] = libraryAddress;
      librariesOptions += `--libraries ${libraryPath}:${libraryName}:${libraryAddress} `;
    });
    console.log(`Found ${librariesNames.length} libraries: ${JSON.stringify(CONTRACT_LIBRARIES)}`);

    let successCount = 0;
    let skipCount = 0;
    let failCount = 0;
    
    const alreadyVerifiedContracts: string[] = [];
    const successfullyVerifiedContracts: string[] = [];
    const failedVerificationContracts: string[] = [];

    for (const contractName of contractNames) {
      const contractAddress = deploymentAddresses[contractName];
      
      console.log(`\n=== Processing ${contractName} at ${contractAddress} ===`);
      
      // if (isContractVerified(contractAddress, networkName, etherscanApiKey)) {
      //   console.log(`✅ ${contractName} is already verified. Skipping.`);
      //   alreadyVerifiedContracts.push(`${contractName} (${contractAddress})`);
      //   skipCount++;
      //   continue;
      // }
      
      const verificationStatus = await verifyContract(contractName, contractAddress, networkName, etherscanApiKey, librariesOptions);
      
      if (verificationStatus === VerificationStatus.Success) {
        successfullyVerifiedContracts.push(`${contractName} (${contractAddress})`);
        successCount++;
      } else if (verificationStatus === VerificationStatus.AlreadyVerified) {
        alreadyVerifiedContracts.push(`${contractName} (${contractAddress})`);
        skipCount++;
      } else {
        failedVerificationContracts.push(`${contractName} (${contractAddress})`);
        failCount++;
      }
    }

    console.log(`\n=== Verification Summary ===`);
    console.log(`Total contracts: ${contractNames.length}`);
    console.log(`Already verified (skipped): ${skipCount}`);
    console.log(`Successfully verified: ${successCount}`);
    console.log(`Failed to verify: ${failCount}`);
    
    if (alreadyVerifiedContracts.length > 0) {
      console.log(`\n=== Already Verified Contracts (${alreadyVerifiedContracts.length}) ===`);
      alreadyVerifiedContracts.forEach((contract, index) => {
        console.log(`${index + 1}. ${contract}`);
      });
    }
    
    if (successfullyVerifiedContracts.length > 0) {
      console.log(`\n=== Successfully Verified Contracts (${successfullyVerifiedContracts.length}) ===`);
      successfullyVerifiedContracts.forEach((contract, index) => {
        console.log(`${index + 1}. ${contract}`);
      });
    }
    
    if (failedVerificationContracts.length > 0) {
      console.log(`\n=== Failed Verification Contracts (${failedVerificationContracts.length}) ===`);
      failedVerificationContracts.forEach((contract, index) => {
        console.log(`${index + 1}. ${contract}`);
      });
    }
    
    if (failCount > 0) {
      process.exit(1);
    }
  } catch (error: any) {
    console.error(`\n❌ Error: ${error.message || error}`);
    process.exit(1);
  }
}

verifyContracts()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(`\n❌ Unhandled error: ${error.message || error}`);
    process.exit(1);
  });
