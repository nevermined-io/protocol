/**
 * This class is used to deploy the test contract using Foundry scripts and Anvil.
 */

import { readFileSync } from 'fs'
import {
  Abi,
  createPublicClient,
  createTestClient,
  createWalletClient,
  decodeErrorResult,
  getContract,
  http,
  parseEventLogs,
  publicActions,
  PublicClient,
  walletActions,
  WalletClient,
  zeroAddress,
} from 'viem'
import fs from 'fs'
import { foundry } from 'viem/chains'

export class FoundryTools {
  private testClient
  private publicClient: PublicClient
  private walletClient: WalletClient

  constructor(
    private readonly wallets: WalletClient[] = [],
    private readonly rpc = 'http://localhost:8545',
  ) {
    this.publicClient = createPublicClient({
      chain: foundry,
      transport: http(rpc),
    })

    this.walletClient = createWalletClient({
      chain: foundry,
      transport: http(rpc),
    })
    this.testClient = createTestClient({
      chain: foundry,
      mode: 'anvil',
      transport: http(rpc),
    })
      .extend(publicActions)
      .extend(walletActions)
  }

  async connectToInstance(
    deploymentJsonPath = 'deployments/latest-hardhat.json',
    backToDeploymentBlock = true,
  ) {
    console.log('Connect to contracts instance...')
    console.log('RPC:', this.rpc)
    const deploymentJson = this.parseDeploymentJson(deploymentJsonPath)
    console.log('Deployment JSON:', deploymentJson)

    const blockNumber = deploymentJson.blockNumber || 0
    const snapshotId = deploymentJson.snapshotId || 0
    if (backToDeploymentBlock && blockNumber > 0) {
      await this.revertToSnapshot(snapshotId)
    }

    const nvmConfig = await this.getContractInstance(
      'NVMConfig',
      deploymentJson.contracts.NVMConfig,
    )
    const assetsRegistry = await this.getContractInstance(
      'AssetsRegistry',
      deploymentJson.contracts.AssetsRegistry,
    )
    const paymentsVault = await this.getContractInstance(
      'PaymentsVault',
      deploymentJson.contracts.PaymentsVault,
    )
    const agreementsStore = await this.getContractInstance(
      'AgreementsStore',
      deploymentJson.contracts.AgreementsStore,
      'artifacts/contracts/agreements',
    )
    const nft1155Credits = await this.getContractInstance(
      'NFT1155Credits',
      deploymentJson.contracts.NFT1155Credits,
      'artifacts/contracts/token',
    )
    const nft1155ExpirableCredits = await this.getContractInstance(
      'NFT1155ExpirableCredits',
      deploymentJson.contracts.NFT1155ExpirableCredits,
      'artifacts/contracts/token',
    )
    const lockPaymentCondition = await this.getContractInstance(
      'LockPaymentCondition',
      deploymentJson.contracts.LockPaymentCondition,
      'artifacts/contracts/conditions',
    )
    const transferCreditsCondition = await this.getContractInstance(
      'TransferCreditsCondition',
      deploymentJson.contracts.TransferCreditsCondition,
      'artifacts/contracts/conditions',
    )
    const distributePaymentsCondition = await this.getContractInstance(
      'DistributePaymentsCondition',
      deploymentJson.contracts.DistributePaymentsCondition,
      'artifacts/contracts/conditions',
    )
    const fiatSettlementCondition = await this.getContractInstance(
      'FiatSettlementCondition',
      deploymentJson.contracts.FiatSettlementCondition,
      'artifacts/contracts/conditions',
    )
    const fixedPaymentTemplate = await this.getContractInstance(
      'FixedPaymentTemplate',
      deploymentJson.contracts.FixedPaymentTemplate,
      'artifacts/contracts/agreements',
    )
    const fiatPaymentTemplate = await this.getContractInstance(
      'FiatPaymentTemplate',
      deploymentJson.contracts.FiatPaymentTemplate,
      'artifacts/contracts/agreements',
    )
    const accessManager = await this.getContractInstance(
      'AccessManager',
      deploymentJson.contracts.AccessManager,
      'artifacts/@openzeppelin/contracts/access/manager',
    )
    return {
      nvmConfig,
      assetsRegistry,
      paymentsVault,
      agreementsStore,
      nft1155Credits,
      nft1155ExpirableCredits,
      lockPaymentCondition,
      transferCreditsCondition,
      distributePaymentsCondition,
      fiatSettlementCondition,
      fixedPaymentTemplate,
      fiatPaymentTemplate,
      accessManager,
    }
  }

  async getContractInstance(
    name: string,
    address: `0x${string}`,
    artifactsFolder = 'artifacts/contracts',
  ) {
    const contract = getContract({
      address,
      abi: FoundryTools.getContractABI(name, artifactsFolder),
      client: { public: this.publicClient, wallet: this.walletClient },
    })
    return contract
  }

  static getContractABI(contractName: string, artifactsFolder = 'artifacts/contracts'): Abi {
    const artifact = JSON.parse(
      fs.readFileSync(`${artifactsFolder}/${contractName}.sol/${contractName}.json`, 'utf8'),
    )
    return artifact.abi
  }

  static getContractArtifact(fullPath: string) {
    const artifact = JSON.parse(fs.readFileSync(fullPath, 'utf8'))
    return artifact
  }

  parseDeploymentJson(deploymentJsonPath: string) {
    const jsonContent = readFileSync(deploymentJsonPath, 'utf8')
    const deploymentJson = JSON.parse(jsonContent)
    return deploymentJson
  }

  async deployContract(contractName: string, args: any[], fullPath: string) {
    const artifact = FoundryTools.getContractArtifact(fullPath)

    const txHash = await this.walletClient.deployContract({
      abi: artifact.abi,
      args,
      name: contractName,
      account: this.wallets[0].account?.address,
      bytecode: artifact.bytecode,
      chain: foundry,
    })

    const tx = await this.publicClient.waitForTransactionReceipt({ hash: txHash })
    const contractAddress = tx.contractAddress

    return getContract({
      abi: artifact.abi,
      address: contractAddress as `0x${string}`,
      client: { public: this.publicClient, wallet: this.walletClient },
    })
  }

  getClients() {
    return {
      testClient: this.testClient,
      publicClient: this.publicClient,
      walletClient: this.walletClient,
    }
  }

  getTestClient() {
    return this.testClient
  }
  getPublicClient() {
    return this.publicClient
  }
  getWalletClient() {
    return this.walletClient
  }

  async getTxEvents(txHash: `0x${string}`) {
    const receipt = await this.publicClient.waitForTransactionReceipt({ hash: txHash })
    if (receipt.status !== 'success') return []
    return receipt.logs
  }

  async getTxParsedLogs(txHash: `0x${string}`, abi: any) {
    const logs = await this.getTxEvents(txHash)
    if (logs.length > 0) return parseEventLogs({ abi, logs }) as any[]
    return []
  }

  async setBlockchainTime(time: number): Promise<void> {}

  async decodeCustomErrorFromTx(txHash: string, abi: Abi) {
    const trace = await this.testClient.request({
      method: 'debug_traceTransaction',
      params: [txHash, {}],
    })

    // Step 4: Get the revert data from the trace
    const revertData = trace?.returnValue
    if (!revertData) {
      console.error('No revert data found in trace.')
      return
    }
    // Step 5: Decode revert data
    const decoded = decodeErrorResult({
      abi,
      data: `0x${revertData}`,
    })

    console.log('Decoded Error:', decoded)
    return decoded
  }

  async createSnapshot() {
    return await this.testClient.request({})
  }

  async revertToSnapshot(snapshotId: bigint) {
    console.log('Resetting blockchain to snapshot:', snapshotId)
    await this.testClient.request({ method: 'evm_revert', params: [snapshotId] })
  }

  // async connectToContracts(deploymentJson: any): Promise<void> {
  //   console.log('Connecting to NVMConfig at address: ', deploymentJson.contracts.NVMConfig)
  //   const _nvmConfig = getContract({
  //     address: deploymentJson.contracts.NVMConfig,
  //     abi: FoundryTools.getContractABI('NVMConfig'),
  //     // 1a. Insert a single client
  //     client: this.testClient,
  //     // // 1b. Or public and/or wallet clients
  //     // client: { public: publicClient, wallet: walletClient }
  //   })
  //   // const _nvmConfig = await hre.viem.getContractAt('NVMConfig', deploymentJson.contracts.NVMConfig)
  //   console.log('Network Fees: ' , await _nvmConfig.read.getNetworkFee())
  // }
}
