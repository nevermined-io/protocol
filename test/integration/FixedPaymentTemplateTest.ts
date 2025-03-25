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

describe('IT: FixedPaymentTemplate comprehensive test', function () {
  // Variables for test state
  let _deployment: any
  let owner: any
  let alice: any
  let bob: any
  let publicClient: any
  let mockERC20: any

  // Setup fixture for deploying contracts
  async function deployModuleFixture() {
    return ignition.deploy(FullDeploymentModule)
  }

  before(async () => {
    const wallets = await hre.viem.getWalletClients()
    owner = wallets[0]
    alice = wallets[3]
    bob = wallets[4]
    publicClient = await hre.viem.getPublicClient()

    _deployment = await loadFixture(deployModuleFixture)

    // Deploy MockERC20 for ERC20 tests
    mockERC20 = await hre.viem.deployContract('MockERC20', ['Test Token', 'TST'])

    // Mint tokens to bob for testing
    await mockERC20.write.mint([bob.account.address, 1000n * 10n ** 18n], {
      account: owner.account,
    })

    console.log(`NVM Config: ${_deployment.nvmConfig.address}`)
    console.log(`Assets Registry: ${_deployment.assetsRegistry.address}`)
    console.log(`Fixed Payment Template: ${_deployment.fixedPaymentTemplate.address}`)
  })

  describe('Native Token Payment Flow', function () {
    let did: `0x${string}`
    let planId: `0x${string}`
    let aliceBalanceBefore: bigint
    let aliceBalanceAfter: bigint
    let bobBalanceBefore: bigint
    let bobBalanceAfter: bigint
    let vaultBalanceBefore: bigint
    let vaultBalanceAfter: bigint

    it('Alice can register an asset with a plan', async () => {
      // Register asset and plan using helper function
      const result = await registerAssetAndPlan(
        _deployment.assetsRegistry,
        zeroAddress,
        alice,
        alice.account.address,
        _deployment.nftCredits.address,
      )

      did = result.did
      planId = result.planId

      expect(did).to.be.a('string').to.startWith('0x')
      expect(planId).to.be.a('string').to.startWith('0x')

      // Verify asset and plan are registered
      const asset = await _deployment.assetsRegistry.read.getAsset([did])
      expect(asset.lastUpdated > 0n).to.be.true

      const plan = await _deployment.assetsRegistry.read.getPlan([planId])
      expect(plan.lastUpdated > 0n).to.be.true
      expect(plan.nftAddress).to.equalIgnoreCase(_deployment.nftCredits.address)
    })

    it('We can check the balances before agreement', async () => {
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

    it('Bob can create an agreement using native token', async () => {
      // Get the plan to determine payment amount
      const plan = await _deployment.assetsRegistry.read.getPlan([planId])
      const totalAmount = plan.price.amounts.reduce((a: bigint, b: bigint) => a + b, 0n)

      const agreementIdSeed = generateId()
      const txHash = await _deployment.fixedPaymentTemplate.write.createAgreement(
        [agreementIdSeed, did, planId, []],
        { account: bob.account, value: totalAmount },
      )

      expect(txHash).to.be.a('string').to.startWith('0x')

      // Verify events from transaction
      const logs = await getTxParsedLogs(publicClient, txHash, _deployment.agreementsStore.abi)

      expect(logs.length).to.be.greaterThan(0)
    })

    it('We can check the credits of Bob', async () => {
      const balance = await _deployment.nftCredits.read.balanceOf([bob.account.address, did])

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
        address: _deployment.paymentsVault.address,
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

  describe('ERC20 Token Payment Flow', function () {
    let did: `0x${string}`
    let planId: `0x${string}`
    let aliceERC20BalanceBefore: bigint
    let aliceERC20BalanceAfter: bigint
    let bobERC20BalanceBefore: bigint
    let bobERC20BalanceAfter: bigint
    let vaultERC20BalanceBefore: bigint
    let vaultERC20BalanceAfter: bigint

    it('Alice can register an asset with ERC20 payment plan', async () => {
      // Register asset and plan with ERC20 token
      const result = await registerAssetAndPlan(
        _deployment.assetsRegistry,
        mockERC20.address,
        alice,
        alice.account.address,
        _deployment.nftCredits.address,
      )

      did = result.did
      planId = result.planId

      expect(did).to.be.a('string').to.startWith('0x')
      expect(planId).to.be.a('string').to.startWith('0x')

      // Verify plan uses ERC20 token
      const plan = await _deployment.assetsRegistry.read.getPlan([planId])
      expect(plan.price.tokenAddress).to.equalIgnoreCase(mockERC20.address)
      expect(plan.nftAddress).to.equalIgnoreCase(_deployment.nftCredits.address)
    })

    it('We can check the ERC20 balances before agreement', async () => {
      aliceERC20BalanceBefore = await mockERC20.read.balanceOf([alice.account.address])
      bobERC20BalanceBefore = await mockERC20.read.balanceOf([bob.account.address])
      vaultERC20BalanceBefore = await mockERC20.read.balanceOf([_deployment.paymentsVault.address])

      console.log('Alice ERC20 Balance Before:', aliceERC20BalanceBefore)
      console.log('Bob ERC20 Balance Before:', bobERC20BalanceBefore)
      console.log('Vault ERC20 Balance Before:', vaultERC20BalanceBefore)
      expect(bobERC20BalanceBefore > 0n).to.be.true
    })

    it('Bob can create an agreement using ERC20 token', async () => {
      // Get the plan to determine payment amount
      const plan = await _deployment.assetsRegistry.read.getPlan([planId])
      const totalAmount = plan.price.amounts.reduce((a: bigint, b: bigint) => a + b, 0n)

      // Approve tokens for LockPaymentCondition
      await mockERC20.write.approve([_deployment.lockPaymentCondition.address, totalAmount], {
        account: bob.account,
      })

      // Also approve tokens for PaymentsVault (needed for DistributePaymentsCondition)
      await mockERC20.write.approve([_deployment.paymentsVault.address, totalAmount], {
        account: bob.account,
      })

      const agreementIdSeed = generateId()
      const txHash = await _deployment.fixedPaymentTemplate.write.createAgreement(
        [agreementIdSeed, did, planId, []],
        { account: bob.account },
      )

      expect(txHash).to.be.a('string').to.startWith('0x')
    })

    it('We can check the credits of Bob for ERC20 payment', async () => {
      const balance = await _deployment.nftCredits.read.balanceOf([bob.account.address, did])

      console.log('Credits Balance for ERC20 payment:', balance)
      expect(balance > 0n).to.be.true
    })

    it('We can check the ERC20 balances after agreement', async () => {
      aliceERC20BalanceAfter = await mockERC20.read.balanceOf([alice.account.address])
      bobERC20BalanceAfter = await mockERC20.read.balanceOf([bob.account.address])
      vaultERC20BalanceAfter = await mockERC20.read.balanceOf([_deployment.paymentsVault.address])

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

  describe('Error Conditions', function () {
    let did: `0x${string}`
    let planId: `0x${string}`

    before(async () => {
      // Register asset and plan
      const result = await registerAssetAndPlan(
        _deployment.assetsRegistry,
        zeroAddress,
        alice,
        alice.account.address,
        _deployment.nftCredits.address,
      )

      did = result.did
      planId = result.planId
    })

    it('Should reject if agreement already exists', async () => {
      // Get the plan to determine payment amount
      const plan = await _deployment.assetsRegistry.read.getPlan([planId])
      const totalAmount = plan.price.amounts.reduce((a: bigint, b: bigint) => a + b, 0n)

      // Create a unique agreement ID seed
      const agreementIdSeed = generateId()

      // Create agreement first time
      await _deployment.fixedPaymentTemplate.write.createAgreement(
        [agreementIdSeed, did, planId, []],
        { account: bob.account, value: totalAmount },
      )

      // Try to create the same agreement again
      await expect(
        _deployment.fixedPaymentTemplate.write.createAgreement([agreementIdSeed, did, planId, []], {
          account: bob.account,
          value: totalAmount,
        }),
      ).to.be.rejectedWith(/AgreementAlreadyRegistered/)
    })

    it('Should reject if asset does not exist', async () => {
      const nonExistentDid = generateId()
      const newAgreementIdSeed = generateId()

      await expect(
        _deployment.fixedPaymentTemplate.write.createAgreement(
          [newAgreementIdSeed, nonExistentDid, planId, []],
          { account: bob.account, value: 100n },
        ),
      ).to.be.rejectedWith(/AssetNotFound/)
    })

    it('Should reject if plan does not exist', async () => {
      const nonExistentPlanId = generateId()
      const newAgreementIdSeed = generateId()

      await expect(
        _deployment.fixedPaymentTemplate.write.createAgreement(
          [newAgreementIdSeed, did, nonExistentPlanId, []],
          { account: bob.account, value: 100n },
        ),
      ).to.be.rejectedWith(/PlanNotFound/)
    })

    it('Should reject if payment amount is incorrect', async () => {
      const newAgreementIdSeed = generateId()

      // Get the plan to determine payment amount
      const plan = await _deployment.assetsRegistry.read.getPlan([planId])
      const totalAmount = plan.price.amounts.reduce((a: bigint, b: bigint) => a + b, 0n)

      // Try with incorrect amount (less than required)
      await expect(
        _deployment.fixedPaymentTemplate.write.createAgreement(
          [newAgreementIdSeed, did, planId, []],
          { account: bob.account, value: totalAmount - 1n },
        ),
      ).to.be.rejectedWith(/InvalidTransactionAmount/)
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

      // Add Nevermined fees
      const result = await _deployment.assetsRegistry.read.addFeesToPaymentsDistribution([
        unsupportedPriceConfig.amounts,
        unsupportedPriceConfig.receivers,
      ])
      unsupportedPriceConfig.amounts = [...result[0]]
      unsupportedPriceConfig.receivers = [...result[1]]

      // Create credits config
      const creditsConfig = createCreditsConfig()

      // Register asset with unsupported price type
      const didSeed = generateId()
      const newDid = await _deployment.assetsRegistry.read.hashDID([didSeed, alice.account.address])

      await _deployment.assetsRegistry.write.registerAssetAndPlan(
        [
          didSeed,
          'https://nevermined.io',
          unsupportedPriceConfig,
          creditsConfig,
          _deployment.nftCredits.address,
        ],
        { account: alice.account },
      )

      // Get the new plan ID
      const asset = await _deployment.assetsRegistry.read.getAsset([newDid])
      const newPlanId = asset.plans[0]

      // Try to create agreement with unsupported price type
      const newAgreementIdSeed = generateId()
      await expect(
        _deployment.fixedPaymentTemplate.write.createAgreement(
          [newAgreementIdSeed, newDid, newPlanId, []],
          { account: bob.account, value: 200n },
        ),
      ).to.be.rejectedWith(/UnsupportedPriceTypeOption/)
    })
  })
})
