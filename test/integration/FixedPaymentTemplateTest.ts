import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { expect } from 'chai'
import hre from 'hardhat'
import {
  generateId,
  getTxParsedLogs,
  createPriceConfig,
  createCreditsConfig,
  registerAssetAndPlan
} from '../common/utils'
import { zeroAddress } from 'viem'
import { FoundryTools } from '../common/FoundryTools'

var chai = require('chai')
chai.use(require('chai-string'))

describe('IT: FixedPaymentTemplate comprehensive test', function () {
  let nvmConfig
  let assetsRegistry
  let nftCredits
  let lockPaymentCondition
  let paymentsVault
  let fixedPaymentTemplate
  let agreementsStore
  let did: any
  let planId: bigint
  let owner: any
  let alice: any
  let bob: any
  let mockERC20
  let priceConfig: any
  let creditsConfig: any
  let foundryTools
  let publicClient
  let walletClient

  before(async () => {
    await loadFixture(deployInstance)
  })

  // Setup fixture for deploying contracts
  async function deployInstance() {
    const wallets = await hre.viem.getWalletClients()

    foundryTools = new FoundryTools(wallets)
    const _deployment = await foundryTools.connectToInstance(process.env.DEPLOYMENT_ADDRESSES_JSON || 'deployment-latest.json')

    nvmConfig = _deployment.nvmConfig
    assetsRegistry = _deployment.assetsRegistry
    paymentsVault = _deployment.paymentsVault
    fixedPaymentTemplate = _deployment.fixedPaymentTemplate
    lockPaymentCondition = _deployment.lockPaymentCondition
    agreementsStore = _deployment.agreementsStore
    nftCredits = _deployment.nft1155Credits

    owner = wallets[0]
    alice = wallets[3]
    bob = wallets[4]

    publicClient = foundryTools.getPublicClient()
    walletClient = foundryTools.getWalletClient()

    mockERC20 = await foundryTools.deployContract(
      'MockERC20',
      ['Test Token', 'TST'],
      'artifacts/contracts/test/MockERC20.sol/MockERC20.json',
    )
    // Mint tokens to bob for testing
    await mockERC20.write.mint([bob.account.address, 1000n * 100n ** 18n], {
      account: owner.account,
    })
    
    return {
      nvmConfig,
      assetsRegistry,
      nftCredits,
      paymentsVault,
      fixedPaymentTemplate,
      lockPaymentCondition,
      agreementsStore,
      owner,
      alice,
      bob,
      mockERC20,
      publicClient,
    }
  }
  describe('Contracts Config', function () {
    it('I can load config', async () => {
      expect((await nvmConfig.read.getNetworkFee()) > 0n).to.be.true
    })
  })
  describe('Native Token Payment Flow', function () {
    let aliceBalanceBefore: bigint
    let aliceBalanceAfter: bigint
    let bobBalanceBefore: bigint
    let bobBalanceAfter: bigint
    let vaultBalanceBefore: bigint
    let vaultBalanceAfter: bigint
    let planId
    let did

    it('Alice can register an asset with a plan', async () => {
      priceConfig = createPriceConfig(zeroAddress, alice.account.address)
      creditsConfig = createCreditsConfig()
      const result = await registerAssetAndPlan(assetsRegistry, priceConfig, creditsConfig, alice, nftCredits.address)
      did = result.did
      planId = result.planId

      const asset = await assetsRegistry.read.getAsset([did])

      // Verify asset and plan are registered
      expect(asset.lastUpdated > 0n).to.be.true

      const plan = await assetsRegistry.read.getPlan([planId])
      expect(plan.lastUpdated > 0n).to.be.true
      expect(plan.nftAddress).to.equalIgnoreCase(nftCredits.address)

      console.log('Plan ID:', planId)
    })

    it('We can check the balances before agreement', async () => {
      aliceBalanceBefore = (await publicClient.getBalance({
        address: alice.account.address,
      })) as bigint

      bobBalanceBefore = (await publicClient.getBalance({
        address: bob.account.address,
      })) as bigint

      vaultBalanceBefore = await publicClient.getBalance({
        address: paymentsVault.address,
      })

      console.log('Alice Balance Before:', aliceBalanceBefore)
      console.log('Bob Balance Before:', bobBalanceBefore)
      console.log('Vault Balance Before:', vaultBalanceBefore)
      expect(bobBalanceBefore > 1n).to.be.true
    })

    it('Bob can create an agreement using native token', async () => {
      // Get the plan to determine payment amount
      const plan = await assetsRegistry.read.getPlan([planId])
      console.log('Before order - Plan ID:', planId)
      console.log(plan)

      const totalAmount = plan.price.amounts.reduce((a: bigint, b: bigint) => a + b, 0n)

      const agreementIdSeed = generateId()
      const txHash = await fixedPaymentTemplate.write.createAgreement(
        [agreementIdSeed, did, planId, []],
        { account: bob.account, value: totalAmount },
      )

      expect(txHash).to.be.a('string').to.startWith('0x')

      // Verify events from transaction
      const logs = await getTxParsedLogs(publicClient, txHash, agreementsStore.abi)

      expect(logs.length).to.be.greaterThan(0)
    })

    it('We can check the credits of Bob', async () => {
      const balance = await nftCredits.read.balanceOf([bob.account.address, planId as any])

      console.log('Credits Balance:', balance)
      expect(balance > 0n).to.be.true
    })

    it('We can check the balances after agreement', async () => {
      aliceBalanceAfter = (await publicClient.getBalance({
        address: alice.account.address,
      })) as bigint

      bobBalanceAfter = (await publicClient.getBalance({
        address: bob.account.address,
      })) as bigint

      vaultBalanceAfter = await publicClient.getBalance({
        address: paymentsVault.address,
      })

      console.log('Alice Balance After:', aliceBalanceAfter)
      console.log('Bob Balance After:', bobBalanceAfter)
      console.log('Vault Balance After:', vaultBalanceAfter)

      // Alice should have received payment
      expect(aliceBalanceAfter > aliceBalanceBefore).to.be.true
      // Bob should have spent ETH
      expect(bobBalanceAfter < bobBalanceBefore).to.be.true
      // Vault should have same balance (payments distributed)
      expect(vaultBalanceAfter == vaultBalanceBefore).to.be.true
    })
  })

  describe('Error Conditions', function () {
    let priceConfig
    let creditsConfig
    let did
    let planId
    let totalAmount
    let asset

    before(async () => {
      priceConfig = createPriceConfig(zeroAddress, bob.account.address)
      creditsConfig = createCreditsConfig()

      const result = await registerAssetAndPlan(assetsRegistry, priceConfig, creditsConfig, alice, nftCredits.address)
      did = result.did
      planId = result.planId

      asset = await assetsRegistry.read.getAsset([did])
      // planId = asset.plans[0]

      console.log(asset)
      // Verify asset and plan are registered
      expect(asset.lastUpdated > 0n).to.be.true
    })

    it('Should reject if agreement already exists', async () => {
      // Get the plan to determine payment amount

      // Create a unique agreement ID seed
      const agreementIdSeed = generateId()
      console.log('Agreement ID Seed:', agreementIdSeed)
      // Create agreement first time
      let txHash = await fixedPaymentTemplate.write.createAgreement(
        [agreementIdSeed, did, planId, []],
        {
          account: bob.account,
          value: totalAmount,
        },
      )
      let tx = await publicClient.waitForTransactionReceipt({ hash: txHash })
      console.log(tx.status)

      txHash = await fixedPaymentTemplate.write.createAgreement(
        [agreementIdSeed, did, planId, []],
        {
          account: bob.account,
          value: totalAmount,
        },
      )
      tx = await publicClient.waitForTransactionReceipt({ hash: txHash })
      expect(tx.status).to.be.a('string').equalIgnoreCase('reverted') // AgreementAlreadyRegistered

      // const customError = await foundryTools.decodeCustomErrorFromTx(txHash, agreementsStore.abi)
      // expect(customError.errorName).to.be.equal('AgreementAlreadyRegistered')
    })

    it('Should reject if asset does not exist', async () => {
      const nonExistentDid = generateId()
      const newAgreementIdSeed = generateId()

      const txHash = await fixedPaymentTemplate.write.createAgreement(
        [newAgreementIdSeed, nonExistentDid, planId, []],
        { account: alice.account, value: 100n },
      )
      const tx = await publicClient.waitForTransactionReceipt({ hash: txHash })
      expect(tx.status).to.be.a('string').equalIgnoreCase('reverted')

      const customError = await foundryTools.decodeCustomErrorFromTx(
        txHash,
        fixedPaymentTemplate.abi,
      )
      expect(customError.errorName).to.be.equal('AssetNotFound')
    })

    it('Should reject if plan does not exist', async () => {
      const nonExistentPlanId = generateId()
      const newAgreementIdSeed = generateId()

      const txHash = await fixedPaymentTemplate.write.createAgreement(
        [newAgreementIdSeed, did, nonExistentPlanId, []],
        { account: alice.account, value: 100n },
      )
      const tx = await publicClient.waitForTransactionReceipt({ hash: txHash })
      expect(tx.status).to.be.a('string').equalIgnoreCase('reverted')

      const customError = await foundryTools.decodeCustomErrorFromTx(
        txHash,
        fixedPaymentTemplate.abi,
      )
      expect(customError.errorName).to.be.equal('PlanNotFound')
    })

    it('Should reject if payment amount is incorrect', async () => {
      const newAgreementIdSeed = generateId()

      // Get the plan to determine payment amount
      const plan = await assetsRegistry.read.getPlan([planId])
      const totalAmount = plan.price.amounts.reduce((a: bigint, b: bigint) => a + b, 0n)

      const txHash = await fixedPaymentTemplate.write.createAgreement(
        [newAgreementIdSeed, did, planId, []],
        {
          account: bob.account,
          value: totalAmount - 1n,
        },
      )
      const tx = await publicClient.waitForTransactionReceipt({ hash: txHash })
      expect(tx.status).to.be.a('string').equalIgnoreCase('reverted') // InvalidTransactionAmount

    })

    it('Should reject unsupported price types', async () => {
      // Create a price config with unsupported price type
      const unsupportedPriceConfig = {
        priceType: 1, // FIXED_FIAT_PRICE (unsupported)
        tokenAddress: zeroAddress,
        amounts: [100n],
        receivers: [alice.account.address],
        contractAddress: zeroAddress,
      }

      const result = await registerAssetAndPlan(assetsRegistry, unsupportedPriceConfig, creditsConfig, alice, nftCredits.address)
      const newDid = result.did
      const newPlanId = result.planId

      // Get the new plan ID
      const asset = await assetsRegistry.read.getAsset([newDid])
      // const newPlanId = asset.plans[0]

      // Try to create agreement with unsupported price type
      const newAgreementIdSeed = generateId()
      const txHash = await fixedPaymentTemplate.write.createAgreement(
        [newAgreementIdSeed, newDid, newPlanId, []],
        {
          account: bob.account,
          value: 200n,
        },
      )
      const tx = await publicClient.waitForTransactionReceipt({ hash: txHash })
      expect(tx.status).to.be.a('string').equalIgnoreCase('reverted')
    })
  })

  describe('ERC20 Token Payment Flow', function () {
    let aliceERC20BalanceBefore: bigint
    let aliceERC20BalanceAfter: bigint
    let bobERC20BalanceBefore: bigint
    let bobERC20BalanceAfter: bigint
    let vaultERC20BalanceBefore: bigint
    let vaultERC20BalanceAfter: bigint

    it('Alice can register an asset with ERC20 payment plan', async () => {

      const priceConfig = createPriceConfig(mockERC20.address, alice.account.address)
      const result = await registerAssetAndPlan(
        assetsRegistry,
        priceConfig,
        createCreditsConfig(),
        alice,
        nftCredits.address)
      did = result.did
      planId = result.planId

      expect(did).to.be.a('string').to.startWith('0x')
      expect(planId > 0n).to.be.true
      console.log('Plan ID:', planId)
      console.log('DID:', did)
      console.log('Price Config:', priceConfig)
      console.log('MockERC20 Address:', mockERC20.address)
      // Verify plan uses ERC20 token
      const plan = await assetsRegistry.read.getPlan([planId])
      console.log('Plan = :', plan)
      expect(plan.price.tokenAddress).to.equalIgnoreCase(mockERC20.address)
      expect(plan.nftAddress).to.equalIgnoreCase(nftCredits.address)
    })

    it('We can check the ERC20 balances before agreement', async () => {
      aliceERC20BalanceBefore = await mockERC20.read.balanceOf([alice.account.address])
      bobERC20BalanceBefore = await mockERC20.read.balanceOf([bob.account.address])
      vaultERC20BalanceBefore = await mockERC20.read.balanceOf([paymentsVault.address])

      console.log('Alice ERC20 Balance Before:', aliceERC20BalanceBefore)
      console.log('Bob ERC20 Balance Before:', bobERC20BalanceBefore)
      console.log('Vault ERC20 Balance Before:', vaultERC20BalanceBefore)
      expect(bobERC20BalanceBefore > 0n).to.be.true
    })

    it('Bob can create an agreement using ERC20 token', async () => {
      // Get the plan to determine payment amount
      const plan = await assetsRegistry.read.getPlan([planId])
      const totalAmount = plan.price.amounts.reduce((a: bigint, b: bigint) => a + b, 0n)

      // Approve tokens for LockPaymentCondition
      await mockERC20.write.approve([lockPaymentCondition.address, totalAmount], {
        account: bob.account,
      })

      // Also approve tokens for PaymentsVault (needed for DistributePaymentsCondition)
      await mockERC20.write.approve([paymentsVault.address, totalAmount], {
        account: bob.account,
      })

      const agreementIdSeed = generateId()
      const txHash = await fixedPaymentTemplate.write.createAgreement(
        [agreementIdSeed, did, planId, []],
        { account: bob.account },
      )

      expect(txHash).to.be.a('string').to.startWith('0x')
    })

    it('We can check the credits of Bob for ERC20 payment', async () => {
      await foundryTools.getTestClient().mine({ blocks: 1 })

      const balance = await nftCredits.read.balanceOf([bob.account.address, planId])

      console.log('Credits Balance for ERC20 payment:', balance)
      expect(balance > 0n).to.be.true
    })

    it('We can check the ERC20 balances after agreement', async () => {
      aliceERC20BalanceAfter = await mockERC20.read.balanceOf([alice.account.address])
      bobERC20BalanceAfter = await mockERC20.read.balanceOf([bob.account.address])
      vaultERC20BalanceAfter = await mockERC20.read.balanceOf([paymentsVault.address])

      console.log('Alice ERC20 Balance After:', aliceERC20BalanceAfter)
      console.log('Bob ERC20 Balance After:', bobERC20BalanceAfter)
      console.log('Vault ERC20 Balance After:', vaultERC20BalanceAfter)

      // Alice should have received payment
      expect(aliceERC20BalanceAfter > aliceERC20BalanceBefore).to.be.true
      // Bob should have spent tokens
      expect(bobERC20BalanceAfter < bobERC20BalanceBefore).to.be.true
      // Vault should have same balance (payments distributed)
      expect(vaultERC20BalanceAfter == vaultERC20BalanceBefore).to.be.true
    })
  })
})
