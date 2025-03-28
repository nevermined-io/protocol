import { keccak256, parseEventLogs, toBytes } from 'viem'
import { execSync } from 'child_process';

export function generateId(): `0x${string}` {
  return keccak256(toBytes(Math.random().toString()))
}

export function sha3(message: string): string {
  return keccak256(toBytes(message))
}

export async function getTxEvents(publicClient: any, txHash: string) {
  const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash })
  if (receipt.status !== 'success') return []
  return receipt.logs
}

export async function getTxParsedLogs(publicClient: any, txHash: string, abi: any) {
  const logs = await getTxEvents(publicClient, txHash)
  if (logs.length > 0) return parseEventLogs({ abi, logs }) as any[]
  return []
}

export interface ForgeAccount {
  mnemonic: string
  index: number
  address: `0x${string}`
}

export function deployContractsWithForge(rpcUrl: string, accountAttributes: ForgeAccount) {
  const command = `forge script scripts/deploy/DeployAll.sol /n
  --extra-output-files abi --rpc-url ${rpcUrl} --broadcast --mnemonics "${accountAttributes.mnemonic}" 
  --mnemonic-indexes ${accountAttributes.index} --sender ${accountAttributes.address} `;

  const output = execSync(command, { encoding: 'utf8' })
  console.log(output)  
}

/**
 * Creates a price configuration object for asset registration
 * @param tokenAddress The address of the token to use for payment
 * @param creatorAddress The address of the asset creator
 * @returns Price configuration object
 */
export function createPriceConfig(tokenAddress: `0x${string}`, creatorAddress: `0x${string}`): any {
  return {
    priceType: 0, // FIXED_PRICE
    tokenAddress: tokenAddress,
    amounts: [100n],
    receivers: [creatorAddress],
    contractAddress: '0x0000000000000000000000000000000000000000',
  }
}

/**
 * Creates a credits configuration object for asset registration
 * @returns Credits configuration object
 */
export function createCreditsConfig(): any {
  return {
    creditsType: 1, // FIXED
    durationSecs: 0n,
    amount: 100n,
    minAmount: 1n,
    maxAmount: 1n,
  }
}

/**
 * Registers an asset and plan in the AssetsRegistry
 * @param assetsRegistry The AssetsRegistry contract instance
 * @param tokenAddress The address of the token to use for payment
 * @param creator The creator account
 * @param creatorAddress The address of the creator
 * @returns Object containing the DID and planId of the registered asset
 */
export async function registerAssetAndPlan(
  assetsRegistry: any,
  tokenAddress: `0x${string}`,
  creator: any,
  creatorAddress: `0x${string}`,
  nftAddress?: `0x${string}`,
): Promise<{ did: `0x${string}`; planId: `0x${string}` }> {
  const didSeed = generateId()
  const did = await assetsRegistry.read.hashDID([didSeed, creatorAddress])

  const priceConfig = createPriceConfig(tokenAddress, creatorAddress)

  const result = await assetsRegistry.read.addFeesToPaymentsDistribution([
    priceConfig.amounts,
    priceConfig.receivers,
  ])
  priceConfig.amounts = [...result[0]]
  priceConfig.receivers = [...result[1]]

  const creditsConfig = createCreditsConfig()

  // Use provided NFT address or default to zero address
  const nftAddressToUse = nftAddress || '0x0000000000000000000000000000000000000000'

  await assetsRegistry.write.registerAssetAndPlan(
    [didSeed, 'https://nevermined.io', priceConfig, creditsConfig, nftAddressToUse],
    { account: creator.account },
  )

  const asset = await assetsRegistry.read.getAsset([did])
  const planId = asset.plans[0]

  return { did, planId }
}

/**
 * Creates an agreement in the AgreementsStore
 * @param agreementsStore The AgreementsStore contract instance
 * @param lockPaymentCondition The LockPaymentCondition contract instance
 * @param did The DID of the asset
 * @param planId The planId of the asset
 * @param user The user account
 * @param template The template account
 * @returns Object containing the agreementId and conditionId
 */
export async function createAgreement(
  agreementsStore: any,
  lockPaymentCondition: any,
  did: `0x${string}`,
  planId: `0x${string}`,
  user: any,
  template: any,
): Promise<{ agreementId: `0x${string}`; conditionId: `0x${string}` }> {
  const agreementSeed = generateId()
  const agreementId = await agreementsStore.read.hashAgreementId([
    agreementSeed,
    user.account.address,
  ])

  const contractName = await lockPaymentCondition.read.NVM_CONTRACT_NAME()
  const conditionId = await lockPaymentCondition.read.hashConditionId([agreementId, contractName])

  await agreementsStore.write.register(
    [agreementId, user.account.address, did, planId, [conditionId], [0], []],
    { account: template.account },
  )

  return { agreementId, conditionId }
}
