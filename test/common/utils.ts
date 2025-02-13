import { keccak256, parseEventLogs, toBytes } from 'viem'

export function sha3(message: string): string {
  return keccak256(toBytes(message))
}

export async function getTxEvents(publicClient: any, txHash: string) {
  const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash })
  if (receipt.status !== 'success') return []
  return receipt.logs
}

export async function getTxParsedLogs(
  publicClient: any,
  txHash: string,
  abi: any,
) {
  const logs = await getTxEvents(publicClient, txHash)
  if (logs.length > 0) return parseEventLogs({ abi, logs }) as any[]
  return []
}
