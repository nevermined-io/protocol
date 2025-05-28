import SafeApiKit from '@safe-global/api-kit'
import Safe from '@safe-global/protocol-kit'
import { MetaTransactionData } from '@safe-global/types-kit'
import { WalletClient } from 'viem'

export function checkEnvVars(envVars: string[]) {
  envVars.forEach((envVar) => {
    if (
      typeof process.env[envVar] === 'undefined' ||
      process.env[envVar]?.trim() === '' ||
      process.env[envVar]?.trim() === '0'
    ) {
      throw new Error(`Environment variable ${envVar} is missing or set to 0`)
    }
  })
  return true
}

export async function proposeTransaction(
  safeAddress: string,
  transactions: MetaTransactionData[],
  wallet: WalletClient,
): Promise<string> {
  const protocolKitOwner = await Safe.init({
    provider: process.env.RPC_URL!,
    signer: process.env.SAFE_SIGNER_PRIVATE_KEY!,
    safeAddress,
  })

  const safeTransaction = await protocolKitOwner.createTransaction({
    transactions,
  })

  const apiKit = new SafeApiKit({
    chainId: BigInt(await wallet.getChainId()),
  })

  const safeTxHash = await protocolKitOwner.getTransactionHash(safeTransaction)

  const senderSignature = await protocolKitOwner.signHash(safeTxHash)

  await apiKit.proposeTransaction({
    safeAddress,
    safeTransactionData: safeTransaction.data,
    safeTxHash,
    senderAddress: wallet.account!.address,
    senderSignature: senderSignature.data,
  })

  console.log(`Transaction hash:${safeTxHash} proposed to Safe... Waiting for confirmation...`)

  return safeTxHash
}
