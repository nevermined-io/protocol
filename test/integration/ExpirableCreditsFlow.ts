import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { ignition } from 'hardhat'
import { expect } from 'chai'
import FullDeploymentModule from '../../ignition/modules/FullDeployment'
import hre from 'hardhat'
import {
  generateId,
  getTxParsedLogs,
  createPriceConfig,
  createCreditsConfig,
  registerAssetAndPlan,
  createAgreement,
} from '../common/utils'
import { zeroAddress } from 'viem'

var chai = require('chai')
chai.use(require('chai-string'))

describe('IT: Expirable Credits e2e flow', function () {
  let _deployment: any
  let alice: any
  let bob: any
  let did: string
  let planId: string
  let agreementId: string
  let publicClient: any
  let aliceBalanceBefore: bigint
  let aliceBalanceAfter: bigint
  let bobBalanceBefore: bigint
  let bobBalanceAfter: bigint
  let vaultBalanceBefore: bigint
  let vaultBalanceAfter: bigint

  let priceConfig = {
    priceType: 0, // Means Fixed Price
    tokenAddress: zeroAddress,
    amounts: [100],
    receivers: [''],
    contractAddress: zeroAddress,
  }
  const creditsConfig = {
    creditsType: 0, // Means Expirable Credits
    durationSecs: 600, // 10 minutes expiration time
    amount: 500,
    minAmount: 1,
    maxAmount: 1,
  }
  let nftAddress: string
  const url = 'https://nevermined.io'

  async function deployModuleFixture() {
    return ignition.deploy(FullDeploymentModule)
  }

  before(async () => {
    const wallets = await hre.viem.getWalletClients()
    alice = wallets[3]
    bob = wallets[4]
    publicClient = await hre.viem.getPublicClient()

    _deployment = await loadFixture(deployModuleFixture)
    expect(_deployment.nvmConfig.address).to.be.a('string').to.startWith('0x')
    expect(_deployment.assetsRegistry.address)
      .to.be.a('string')
      .to.startWith('0x')

    console.log(`NVM Config: ${_deployment.nvmConfig.address}`)
    console.log(`Assets Registry: ${_deployment.assetsRegistry.address}`)
  })

  it('Alice can define the fees of the plan', async () => {
    priceConfig.receivers = [alice.account.address]
    const feesSetup =
      await _deployment.assetsRegistry.read.addFeesToPaymentsDistribution([
        priceConfig.amounts,
        priceConfig.receivers,
      ])
    priceConfig.amounts = feesSetup[0]
    priceConfig.receivers = feesSetup[1]
    console.log('Fees Setup:', feesSetup)
    console.log('Price Config:', priceConfig)
    console.log('Credits Config:', creditsConfig)
    expect(priceConfig.amounts.length).to.be.equal(2)
    expect(priceConfig.receivers.length).to.be.equal(2)
    nftAddress = _deployment.nftExpirableCredits.address
    console.log('NFT1155ExpirableCredits Address:', nftAddress)
    expect(nftAddress).to.be.a('string').to.startWith('0x')
  })

  it('Alice can register an asset with a plan with expirable credits', async () => {
    console.log(`Alice: ${alice.account.address}`)
    const didSeed = generateId()
    did = await _deployment.assetsRegistry.read.hashDID(
      [didSeed, alice.account.address],
      { from: alice.account },
    )

    expect(did).to.be.a('string').to.startWith('0x')
    console.log(`DID SEED: ${didSeed}`)
    console.log(`DID: ${did}`)

    const txHash = await _deployment.assetsRegistry.write.registerAssetAndPlan(
      [didSeed, url, priceConfig, creditsConfig, nftAddress],
      { account: alice.account },
    )
    expect(txHash).to.be.a('string').to.startWith('0x')
    console.log('txHash:', txHash)
    const logs = await getTxParsedLogs(
      publicClient,
      txHash,
      _deployment.assetsRegistry.abi,
    )

    console.log('Logs:', logs)
    expect(logs.length).to.be.equal(2)
  })

  it('Bob can find the asset', async () => {
    const asset = await _deployment.assetsRegistry.read.getAsset([did])
    console.log('Asset = :', asset)
    expect(asset.lastUpdated > 0n).to.be.true
    planId = asset.plans[0]
    expect(planId).to.be.a('string').to.startWith('0x')

    console.log('Plan ID:', planId)
    const plan = await _deployment.assetsRegistry.read.getPlan([planId])
    console.log('Plan = :', plan)
    
    // Verify the plan has expirable credits
    expect(plan.credits.creditsType).to.equal(0) // 0 = EXPIRABLE
    expect(plan.credits.durationSecs).to.equal(600n) // 10 minutes
  })

  it('We can check the balances of Alice, Bob and the Vault contract', async () => {
    aliceBalanceBefore = (await publicClient.getBalance({
      address: alice.account.address,
    })) as bigint
    bobBalanceBefore = (await publicClient.getBalance({
      address: bob.account.address,
    })) as bigint
    vaultBalanceBefore = await publicClient.getBalance({
      address: _deployment.paymentsVault.address,
    })

    console.log('Alice Balance Before:', aliceBalanceBefore)
    console.log('Bob Balance Before:', bobBalanceBefore)
    console.log('Vault Balance Before:', vaultBalanceBefore)
    expect(bobBalanceBefore > 1n).to.be.true
  })

  it('Bob can order an asset using Native token', async () => {
    const totalAmount = priceConfig.amounts.reduce((a, b) => a + BigInt(b), 0n)
    console.log(
      `Bob: ${bob.account.address} paying ${totalAmount} of token ${priceConfig.tokenAddress}`,
    )

    const agreementIdSeed = generateId()
    const txHash = await _deployment.fixedPaymentTemplate.write.createAgreement(
      [agreementIdSeed, did, planId, []],
      { account: bob.account, value: totalAmount },
    )
    expect(txHash).to.be.a('string').to.startWith('0x')
    console.log('txHash:', txHash)
  })

  it('We can check the credits of Bob', async () => {
    const balance = await _deployment.nftExpirableCredits.read.balanceOf([
      bob.account.address,
      did,
    ])
    console.log('Credits Balance:', balance)
    expect(balance > 0n).to.be.true
  })

  it('We can check the balances of Alice, Bob and the Vault are different', async () => {
    aliceBalanceAfter = (await publicClient.getBalance({
      address: alice.account.address,
    })) as bigint
    bobBalanceAfter = (await publicClient.getBalance({
      address: bob.account.address,
    })) as bigint
    vaultBalanceAfter = await publicClient.getBalance({
      address: _deployment.paymentsVault.address,
    })

    console.log('Alice Balance After:', aliceBalanceAfter)
    console.log('Bob Balance After:', bobBalanceAfter)
    console.log('Vault Balance After:', vaultBalanceAfter)

    expect(aliceBalanceAfter > aliceBalanceBefore).to.be.true
    expect(bobBalanceAfter < bobBalanceBefore).to.be.true
    expect(vaultBalanceAfter == vaultBalanceBefore).to.be.true
  })

  it('Credits expire after their duration', async () => {
    // First verify Bob has credits
    const balanceBefore = await _deployment.nftExpirableCredits.read.balanceOf([
      bob.account.address,
      did,
    ])
    expect(balanceBefore > 0n).to.be.true
    console.log('Credits Balance Before Time Advance:', balanceBefore)

    // Advance blockchain time past the expiration period
    await hre.network.provider.send("evm_increaseTime", [601]) // 10 minutes + 1 second
    await hre.network.provider.send("evm_mine")

    // Note: This test may need adjustment since the actual expiration check
    // mechanism would typically be implemented in a "use credits" function
    // which doesn't appear to be fully implemented yet
    
    // Here we would ideally call a function that checks if credits are still valid
    // For now, we'll just document that this is where we would check expiration
    console.log('Time has been advanced past expiration period (10 minutes)')
    console.log('Credits should now be expired')
    
    // Check if credits are expired by checking balance after expiration
    const balanceAfter = await _deployment.nftExpirableCredits.read.balanceOf([
      bob.account.address,
      did,
    ])
    expect(balanceAfter).to.equal(0n) // Balance should be 0 after expiration
  })
})
