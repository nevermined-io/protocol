import { keccak256, parseEventLogs, toBytes, WalletClient } from 'viem'

type CreditsBurnProofData = {
  keyspace: bigint
  nonce: bigint
  planIds: bigint[]
}

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
    redemptionType: 0, // ONLY_GLOBAL_ROLE
    proofRequired: false,
    durationSecs: 0n,
    amount: 100n,
    minAmount: 1n,
    maxAmount: 1n,
  }
}

export const createCreditsBurnProof = (
  keyspace: bigint,
  nonce: bigint,
  planIds: bigint[],
): CreditsBurnProofData => ({
  keyspace,
  nonce,
  planIds,
})

export function createExpirableCreditsConfig(): any {
  return {
    creditsType: 0, // Expirable
    redemptionType: 0, // ONLY_GLOBAL_ROLE
    durationSecs: 60n, // 60 secs
    amount: 100n,
    minAmount: 1n,
    maxAmount: 1n,
  }
}

export async function registerPlan(
  assetsRegistry: any,
  publisher: any,
  priceConfig: any,
  creditsConfig: any,
  nftCreditsAddress: string,
): Promise<any> {
  const result = await assetsRegistry.read.addFeesToPaymentsDistribution([
    priceConfig.amounts,
    priceConfig.receivers,
  ])
  const [_amounts, _receivers] = result
  priceConfig.amounts = _amounts
  priceConfig.receivers = _receivers

  const planId = await assetsRegistry.read.hashPlanId([
    priceConfig,
    creditsConfig,
    nftCreditsAddress,
    publisher.account.address,
  ])
  try {
    await assetsRegistry.write.createPlan([priceConfig, creditsConfig, nftCreditsAddress], {
      account: publisher.account,
    })
  } catch (e) {
    console.log('Plan already registered: ', planId)
  }

  return planId
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
  priceConfig: any,
  creditsConfig: any,
  creator: any,
  nftAddress?: `0x${string}`,
): Promise<{ did: `0x${string}`; planId: bigint }> {
  const didSeed = generateId()
  const did = await assetsRegistry.read.hashDID([didSeed, creator.account.address])

  const nonce = getRandomBigInt()
  const areFeesIncluded = await assetsRegistry.read.areNeverminedFeesIncluded([
    priceConfig.amounts,
    priceConfig.receivers,
  ])
  if (!areFeesIncluded) {
    const result = await assetsRegistry.read.addFeesToPaymentsDistribution([
      priceConfig.amounts,
      priceConfig.receivers,
    ])
    priceConfig.amounts = [...result[0]]
    priceConfig.receivers = [...result[1]]
  }

  // const creditsConfig = createCreditsConfig()

  // Use provided NFT address or default to zero address
  const nftAddressToUse = nftAddress || '0x0000000000000000000000000000000000000000'

  const planId = await assetsRegistry.read.hashPlanId([
    priceConfig,
    creditsConfig,
    nftAddressToUse,
    creator.account.address,
    nonce,
  ])
  await assetsRegistry.write.createPlan([priceConfig, creditsConfig, nftAddressToUse, nonce], {
    account: creator.account,
  })

  await assetsRegistry.write.register([didSeed, 'https://nevermined.io', [planId]], {
    account: creator.account,
  })

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
  planId: bigint,
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
    [agreementId, user.account.address, planId, [conditionId], [0], []],
    { account: template.account },
  )

  return { agreementId, conditionId }
}

export function getRandomBigInt(bits = 128): bigint {
  const bytes = Math.ceil(bits / 8)
  const array = new Uint8Array(bytes)
  crypto.getRandomValues(array)

  let result = 0n
  for (const byte of array) {
    result = (result << 8n) | BigInt(byte)
  }

  return result
}

export async function signCreditsBurnProof(
  walletClient: WalletClient,
  nft1155Address: `0x${string}`,
  proof: CreditsBurnProofData,
): Promise<`0x${string}`> {
  const domain = {
    name: 'NFT1155Base',
    version: '1',
    chainId: await walletClient.getChainId(),
    verifyingContract: nft1155Address,
  }

  const types = {
    CreditsBurnProofData: [
      { name: 'keyspace', type: 'uint256' },
      { name: 'nonce', type: 'uint256' },
      { name: 'planIds', type: 'uint256[]' },
    ],
  }

  const signature = await walletClient.signTypedData({
    account: walletClient.account!,
    domain,
    types,
    primaryType: 'CreditsBurnProofData',
    message: proof,
  })

  return signature
}
