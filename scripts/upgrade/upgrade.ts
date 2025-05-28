import { privateKeyToAccount } from 'viem/accounts'
import { checkEnvVars, proposeTransaction } from './utils'
import * as dotenv from 'dotenv'
import {
  http,
  createWalletClient,
  encodeFunctionData,
  parseAbi,
  createPublicClient,
  PublicClient,
  WalletClient,
} from 'viem'
import { Chain } from 'viem/chains'

// UPGRADE_ROLE from contracts/common/Roles.sol
const UPGRADE_ROLE = 16061234310146353691n
const UPGRADE_DELAY_BUFFER = 60n // seconds

dotenv.config({ path: '.env.upgrades' })

// Common ABIs
const ACCESS_MANAGER_ABI = [
  'function getAccess(uint64 roleId, address account) public view returns (uint48 since, uint32 currentDelay, uint32 pendingDelay, uint48 effect)',
  'function hashOperation(address caller, address target, bytes calldata data) public view returns (bytes32)',
  'function getSchedule(bytes32 id) public view returns (uint48)',
  'function execute(address target, bytes calldata data) public payable returns (uint32)',
  'function schedule(address target, bytes calldata data, uint48 when) external returns (bytes32 operationId)',
]

const UUPS_UPGRADEABLE_ABI = [
  'function upgradeToAndCall(address newImplementation, bytes memory data) external payable',
]

// Shared contract setup function
interface ContractSetup {
  publicClient: PublicClient
  walletClient: WalletClient
  accessManagerAbi: any
  uupsUpgradeableAbi: any
  chainId: number
}

async function setupContracts(): Promise<ContractSetup> {
  const requiredEnvVars = [
    'RPC_URL',
    'PROXY_ADDRESS',
    'NEW_IMPLEMENTATION_ADDRESS',
    'SAFE_ADDRESS',
    'SAFE_SIGNER_PRIVATE_KEY',
    'ACCESS_MANAGER_ADDRESS',
  ]

  checkEnvVars(requiredEnvVars)

  const publicClient = createPublicClient({
    transport: http(process.env.RPC_URL),
  })

  const chainId = await publicClient.getChainId()
  console.log(`Connected to chain ID: ${chainId}`)

  const chain: Chain = {
    id: chainId,
    name: `Chain ${chainId}`,
    nativeCurrency: { name: 'Native Token', symbol: 'ETH', decimals: 18 },
    rpcUrls: {
      default: { http: [process.env.RPC_URL!] },
      public: { http: [process.env.RPC_URL!] },
    },
  }

  const walletClient = createWalletClient({
    account: privateKeyToAccount(process.env.SAFE_SIGNER_PRIVATE_KEY as `0x${string}`),
    chain,
    transport: http(process.env.RPC_URL),
  })

  const accessManagerAbi = parseAbi(ACCESS_MANAGER_ABI)
  const uupsUpgradeableAbi = parseAbi(UUPS_UPGRADEABLE_ABI)

  return {
    publicClient,
    walletClient,
    accessManagerAbi,
    uupsUpgradeableAbi,
    chainId,
  }
}

// Generate upgrade call data
function generateUpgradeCallData(uupsUpgradeableAbi: any): `0x${string}` {
  return encodeFunctionData({
    abi: uupsUpgradeableAbi,
    functionName: 'upgradeToAndCall',
    args: [process.env.NEW_IMPLEMENTATION_ADDRESS as `0x${string}`, '0x' as `0x${string}`],
  })
}

async function initiateContractUpgrade() {
  const { publicClient, walletClient, accessManagerAbi, uupsUpgradeableAbi } =
    await setupContracts()

  // Get upgrade delay from AccessManager
  const accessResult = (await publicClient.readContract({
    address: process.env.ACCESS_MANAGER_ADDRESS as `0x${string}`,
    abi: accessManagerAbi,
    functionName: 'getAccess',
    args: [UPGRADE_ROLE, process.env.SAFE_ADDRESS as `0x${string}`],
  })) as any

  const upgradeDelay = BigInt(accessResult[1])
  console.log(`Retrieved upgrade delay for Safe: ${upgradeDelay} seconds`)

  const currentTime = BigInt(Math.floor(Date.now() / 1000))
  const upgradeTime = currentTime + upgradeDelay + UPGRADE_DELAY_BUFFER

  console.log(
    `Scheduling upgrade for proxy ${process.env.PROXY_ADDRESS} to implementation ${process.env.NEW_IMPLEMENTATION_ADDRESS}`,
  )
  console.log(
    `Upgrade will be executable after timestamp: ${upgradeTime} (${new Date(Number(upgradeTime) * 1000).toISOString()})`,
  )

  const upgradeCallData = generateUpgradeCallData(uupsUpgradeableAbi)

  const accessManagerScheduleData = encodeFunctionData({
    abi: accessManagerAbi,
    functionName: 'schedule',
    args: [process.env.PROXY_ADDRESS as `0x${string}`, upgradeCallData, Number(upgradeTime)],
  })

  const scheduleTransaction = {
    to: process.env.ACCESS_MANAGER_ADDRESS as `0x${string}`,
    value: BigInt(0),
    data: accessManagerScheduleData as `0x${string}`,
  }

  const safeTxHash = await proposeTransaction(
    process.env.SAFE_ADDRESS as string,
    [
      {
        to: scheduleTransaction.to,
        value: '0',
        data: scheduleTransaction.data,
      },
    ],
    walletClient,
  )

  console.log('Transaction proposed to Safe with hash:', safeTxHash)
  console.log('Please review and sign the transaction in your Safe interface')
}

async function finalizeContractUpgrade() {
  const { publicClient, walletClient, accessManagerAbi, uupsUpgradeableAbi } =
    await setupContracts()

  // Prepare the upgrade call data
  const upgradeCallData = generateUpgradeCallData(uupsUpgradeableAbi)

  // Get the operationId for the scheduled upgrade
  const operationId = await publicClient.readContract({
    address: process.env.ACCESS_MANAGER_ADDRESS as `0x${string}`,
    abi: accessManagerAbi,
    functionName: 'hashOperation',
    args: [
      process.env.SAFE_ADDRESS as `0x${string}`,
      process.env.PROXY_ADDRESS as `0x${string}`,
      upgradeCallData,
    ],
  })

  // Check if the operation is scheduled and ready to execute
  const scheduledTimeRaw = await publicClient.readContract({
    address: process.env.ACCESS_MANAGER_ADDRESS as `0x${string}`,
    abi: accessManagerAbi,
    functionName: 'getSchedule',
    args: [operationId],
  })

  // Ensure scheduledTime is a bigint
  const scheduledTime = BigInt(String(scheduledTimeRaw))

  if (scheduledTime === 0n) {
    console.error('No scheduled upgrade found for this operation')
    process.exit(1)
  }

  const currentTime = BigInt(Math.floor(Date.now() / 1000))
  if (currentTime < scheduledTime) {
    console.error(
      `Upgrade not ready yet. Current time: ${currentTime}, scheduled time: ${scheduledTime}`,
    )
    // Calculate remaining time (with proper bigint handling)
    const remainingTimeBigInt = scheduledTime - currentTime
    const remainingTime = Number(remainingTimeBigInt)
    const remainingHours = Math.floor(remainingTime / 3600)
    const remainingMinutes = Math.floor((remainingTime % 3600) / 60)
    const remainingSeconds = remainingTime % 60
    console.error(`Time remaining: ${remainingHours}h ${remainingMinutes}m ${remainingSeconds}s`)
    process.exit(1)
  }

  console.log('Executing scheduled contract upgrade')
  console.log(`Proxy: ${process.env.PROXY_ADDRESS}`)
  console.log(`New implementation: ${process.env.NEW_IMPLEMENTATION_ADDRESS}`)

  // Execute the upgrade by calling the AccessManager execute function
  const executeData = encodeFunctionData({
    abi: accessManagerAbi,
    functionName: 'execute',
    args: [process.env.PROXY_ADDRESS as `0x${string}`, upgradeCallData],
  })

  const executeTransaction = {
    to: process.env.ACCESS_MANAGER_ADDRESS as `0x${string}`,
    value: BigInt(0),
    data: executeData as `0x${string}`,
  }

  const safeTxHash = await proposeTransaction(
    process.env.SAFE_ADDRESS as string,
    [
      {
        to: executeTransaction.to,
        value: '0',
        data: executeTransaction.data,
      },
    ],
    walletClient,
  )

  console.log('Upgrade execution transaction proposed to Safe with hash:', safeTxHash)
  console.log('Please review and sign the transaction in your Safe interface')
}

async function main() {
  const args = process.argv.slice(2)

  if (args.includes('--initiate')) {
    console.log('Initiating contract upgrade process...')
    await initiateContractUpgrade()
  } else if (args.includes('--finalize')) {
    console.log('Finalizing contract upgrade...')
    await finalizeContractUpgrade()
  } else {
    console.log('Please specify either --initiate or --finalize')
    console.log('Example: node scripts/upgrade/upgrade.js --initiate')
    console.log('Example: node scripts/upgrade/upgrade.js --finalize')
    process.exit(1)
  }
}

main().catch((error) => {
  console.error('Error:', error)
  process.exit(1)
})
