import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { FoundryTools } from '../common/FoundryTools'
import { expect } from 'chai'
import hre from 'hardhat'
import {
  generateId,
  createPriceConfig,
  createCreditsConfig,
  registerAssetAndPlan,
} from '../common/utils'
import { zeroAddress } from 'viem'

var chai = require('chai')
chai.use(require('chai-string'))

describe('IT: FiatPaymentTemplate comprehensive test', function () {
  let nvmConfig
  let assetsRegistry
  let nftCredits
  let fiatSettlementCondition
  let paymentsVault
  let fiatPaymentTemplate
  let agreementsStore
  let did: any
  let planId: bigint
  let owner: any
  let alice: any
  let fiatOracle: any
  let bob: any
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
    const _deployment = await foundryTools.connectToInstance(process.env.DEPLOYMENT_ADDRESSES_JSON)
    
    nvmConfig = _deployment.nvmConfig
    assetsRegistry = _deployment.assetsRegistry
    paymentsVault = _deployment.paymentsVault
    fiatPaymentTemplate = _deployment.fiatPaymentTemplate
    fiatSettlementCondition = _deployment.fiatSettlementCondition
    agreementsStore = _deployment.agreementsStore
    nftCredits = _deployment.nft1155Credits

    owner = wallets[0]
    alice = wallets[3]
    bob = wallets[4]
    fiatOracle = wallets[5]
    publicClient = foundryTools.getPublicClient()
    walletClient = foundryTools.getWalletClient()

    const FIAT_SETTLEMENT_ROLE = await fiatSettlementCondition.read.FIAT_SETTLEMENT_ROLE()

    await nvmConfig.write.grantRole([FIAT_SETTLEMENT_ROLE, fiatOracle.account.address], {
      account: owner.account,
    })

    return {
      nvmConfig,
      assetsRegistry,
      nftCredits,
      paymentsVault,
      fixedPaymentTemplate: fiatPaymentTemplate,
      lockPaymentCondition: fiatSettlementCondition,
      agreementsStore,
      owner,
      alice,
      bob,
      fiatOracle,
      publicClient,
    }
  }

  describe('FIAT Payment Flow', function () {
    it('Alice can register an asset with a plan', async () => {
      priceConfig = createPriceConfig(zeroAddress, alice.account.address)
      creditsConfig = createCreditsConfig()

      priceConfig.priceType = 1 // FIXED_FIAT_PRICE
      const result = await registerAssetAndPlan(assetsRegistry, priceConfig, creditsConfig, alice, nftCredits.address)
      did = result.did
      planId = result.planId
      // console.log('Price Config:', priceConfig)


      const asset = await assetsRegistry.read.getAsset([did])
      
      console.log('Asset:', asset)

      // Verify asset and plan are registered
      expect(asset.lastUpdated > 0n).to.be.true

      const plan = await assetsRegistry.read.getPlan([planId])
      expect(plan.lastUpdated > 0n).to.be.true
      expect(plan.nftAddress).to.equalIgnoreCase(nftCredits.address)

      console.log('Plan ID:', planId)
    })

    it('We can check the credits of Bob BEFORE the fiat payment flow', async () => {
      const balance = await nftCredits.read.balanceOf([bob.account.address, planId as any])

      console.log('Credits Balance:', balance)
      // expect(balance == 0n).to.be.true
    })

    it('Fiat Oracle can create an agreement', async () => {
      // Get the plan to determine payment amount
      const plan = await assetsRegistry.read.getPlan([planId])
      console.log('Before order - Plan ID:', planId)
      console.log(plan)
      console.log(did)

      const agreementIdSeed = generateId()
      const txHash = await fiatPaymentTemplate.write.createAgreement(
        [agreementIdSeed, planId, bob.account.address, []],
        { account: fiatOracle.account },
      )

      expect(txHash).to.be.a('string').to.startWith('0x')

      // Verify events from transaction
      const logs = await foundryTools.getTxParsedLogs(txHash, agreementsStore.abi)

      expect(logs.length).to.be.greaterThan(0)
    })

    it('We can check the credits of Bob BEFORE the fiat payment flow', async () => {
      const balance = await nftCredits.read.balanceOf([bob.account.address, planId as any])

      console.log('Credits Balance:', balance)
      expect(balance > 0n).to.be.true
    })
  })

  describe('Error Conditions', function () {
    it('Should reject if agreement already exists', async () => {
      // Get the plan to determine payment amount

      const plan = await assetsRegistry.read.getPlan([planId])

      // Create a unique agreement ID seed
      const agreementIdSeed = generateId()

      // Create agreement first time
      await fiatPaymentTemplate.write.createAgreement(
        [agreementIdSeed, planId, bob.account.address, []],
        {
          account: fiatOracle.account,
        },
      )

      const txHash = await fiatPaymentTemplate.write.createAgreement(
        [agreementIdSeed, planId, bob.account.address, []],
        {
          account: fiatOracle.account,
        })
      const tx = await publicClient.waitForTransactionReceipt({ hash: txHash })
      expect(tx.status).to.be.a('string').equalIgnoreCase('reverted')
      const customError = await foundryTools.decodeCustomErrorFromTx(txHash, agreementsStore.abi)
      expect(customError.errorName).to.be.equal('AgreementAlreadyRegistered')
    })

    it('Should reject if plan does not exist', async () => {
      const nonExistentPlanId = generateId()
      const newAgreementIdSeed = generateId()

      const txHash = await fiatPaymentTemplate.write.createAgreement(
        [newAgreementIdSeed, nonExistentPlanId, bob.account.address, []],
        { account: fiatOracle.account },
      )
      const tx = await publicClient.waitForTransactionReceipt({ hash: txHash })
      // /PlanNotFound/
      expect(tx.status).to.be.a('string').equalIgnoreCase('reverted')
    })

    it('Should reject unsupported price types', async () => {
      // Create a price config with unsupported price type
      const unsupportedPriceConfig = {
        priceType: 2, // SMART_CONTRACT_PRICE (unsupported)
        tokenAddress: zeroAddress,
        amounts: [100n],
        receivers: [alice.account.address],
        contractAddress: zeroAddress,
      }

      // Create credits config
      const creditsConfig = createCreditsConfig()

      // Register asset with unsupported price type
      const didSeed = generateId()
      const newDid = await assetsRegistry.read.hashDID([didSeed, alice.account.address])

      await assetsRegistry.write.registerAssetAndPlan(
        [
          didSeed,
          'https://nevermined.io',
          unsupportedPriceConfig,
          creditsConfig,
          nftCredits.address,
        ],
        { account: alice.account },
      )

      // Get the new plan ID
      const asset = await assetsRegistry.read.getAsset([newDid])
      const newPlanId = asset.plans[0]

      console.log('New Plan ID:', newPlanId)
      console.log('New DID:', newDid)
      // Try to create agreement with unsupported price type
      const newAgreementIdSeed = generateId()
      const txHash = await fiatPaymentTemplate.write.createAgreement(
        [newAgreementIdSeed, newPlanId, bob.account.address, []],
        {
          account: fiatOracle.account,
        },
      )
      const tx = await publicClient.waitForTransactionReceipt({ hash: txHash })
      // // /OnlyPlanWithFiatPrice/
      expect(tx.status).to.be.a('string').equalIgnoreCase('reverted')


      // await expect(
      //   ,
      // ).to.be.rejectedWith(/OnlyPlanWithFiatPrice/)
    })
  })
})
