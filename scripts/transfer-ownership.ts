


import { createPublicClient, http, createWalletClient, parseAbi } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { hardhat } from 'viem/chains';


const contractNames = [
  "NVMConfig",
  "AssetsRegistry",
  "PaymentsVault",
  "NFT1155Credits",
  "NFT1155ExpirableCredits",
  "AgreementsStore",
  "FixedPaymentTemplate",
  "LockPaymentCondition",
  "TransferCreditsCondition",
  "DistributePaymentsCondition"
];

const ownableAbi = parseAbi([
  'function owner() view returns (address)',
  'function transferOwnership(address newOwner)'
]);

async function main() {
  console.log("Starting ownership transfer process...");
  
  const newOwnerAddress = process.env.NEW_OWNER_ADDRESS;
  
  if (!newOwnerAddress) {
    console.error("Error: Please provide a valid Ethereum address as NEW_OWNER_ADDRESS environment variable");
    process.exit(1);
  }
  
  console.log(`New owner address: ${newOwnerAddress}`);
  
  const publicClient = createPublicClient({
    chain: hardhat,
    transport: http()
  });
  
  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    console.error("Error: Please provide a PRIVATE_KEY environment variable");
    process.exit(1);
  }
  
  const account = privateKeyToAccount(privateKey as `0x${string}`);
  const walletClient = createWalletClient({
    account,
    chain: hardhat,
    transport: http()
  });
  
  for (const contractName of contractNames) {
    try {
      console.log(`\nTransferring ownership of ${contractName}...`);
      
      const contractAddress = process.env[`${contractName.toUpperCase()}_ADDRESS`];
      
      if (!contractAddress) {
        console.warn(`Warning: No address found for ${contractName}, skipping...`);
        continue;
      }
      
      const currentOwner = await publicClient.readContract({
        address: contractAddress as `0x${string}`,
        abi: ownableAbi,
        functionName: 'owner'
      });
      
      console.log(`Current owner: ${currentOwner}`);
      
      const hash = await walletClient.writeContract({
        address: contractAddress as `0x${string}`,
        abi: ownableAbi,
        functionName: 'transferOwnership',
        args: [newOwnerAddress as `0x${string}`]
      });
      
      console.log(`Transaction hash: ${hash}`);
      
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      
      console.log(`Ownership of ${contractName} successfully transferred to ${newOwnerAddress}`);
    } catch (error) {
      console.error(`Error transferring ownership of ${contractName}:`, error);
    }
  }
  
  console.log("\nOwnership transfer process completed.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
