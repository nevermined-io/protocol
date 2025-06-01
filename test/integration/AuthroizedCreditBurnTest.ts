import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { expect } from 'chai'
import hre from 'hardhat'
import {
  generateId,
  getTxParsedLogs,
  createPriceConfig,
  createCreditsConfig,
  registerAssetAndPlan,
  createCreditsBurnProof,
  signCreditsBurnProof,
  sleep,
} from '../common/utils'
import { zeroAddress } from 'viem'
import { FoundryTools } from '../common/FoundryTools'
import { WalletClient } from 'viem'

var chai = require('chai')
chai.use(require('chai-string'))

describe('IT: FixedPaymentTemplate comprehensive test with authorized credit burn', function () {
  let nvmConfig
  let assetsRegistry
  let nftCredits
  let lockPaymentCondition
  let paymentsVault
  let fixedPaymentTemplate
  let agreementsStore
  let accessManager
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
  let bobCreditsBalance: bigint
  let creditsBurnerWallet: WalletClient
  let protocolStandardFees: any

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
    fixedPaymentTemplate = _deployment.fixedPaymentTemplate
    lockPaymentCondition = _deployment.lockPaymentCondition
    agreementsStore = _deployment.agreementsStore
    nftCredits = _deployment.nft1155Credits
    accessManager = _deployment.accessManager
    protocolStandardFees = _deployment.protocolStandardFees

    owner = wallets[0]
    alice = wallets[3]
    bob = wallets[4]
    creditsBurnerWallet = wallets[5]

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

    const CREDITS_BURNER_ROLE = 16934877136143260882n
    await accessManager.write.grantRole(
      [CREDITS_BURNER_ROLE, creditsBurnerWallet.account?.address, 0],
      {
        account: owner.account,
      },
    )

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
      // Set the credits config to require proofs
      creditsConfig.proofRequired = true
      const result = await registerAssetAndPlan(
        assetsRegistry,
        priceConfig,
        creditsConfig,
        alice,
        nftCredits.address,
        protocolStandardFees.address,
      )
      did = result.did
      planId = result.planId

      await sleep(2000)

      const asset = await assetsRegistry.read.getAsset([did])

      console.log(' **** Result:', result)
      console.log(' **** Asset:', asset)

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
        [agreementIdSeed, planId, []],
        { account: bob.account, value: totalAmount },
      )

      expect(txHash).to.be.a('string').to.startWith('0x')

      // Verify events from transaction
      const logs = await getTxParsedLogs(publicClient, txHash, agreementsStore.abi)

      expect(logs.length).to.be.greaterThan(0)
    })

    it('We can check the credits of Bob', async () => {
      bobCreditsBalance = await nftCredits.read.balanceOf([bob.account.address, planId as any])

      console.log('Credits Balance:', bobCreditsBalance)
      expect(bobCreditsBalance > 0n).to.be.true
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

    it("Owner cannot burn Bob's credits without Bob's approval", async () => {
      const balance = await nftCredits.read.balanceOf([bob.account.address, planId as any])
      expect(balance).to.equal(bobCreditsBalance)

      // Sign the credits burn proof with owner instead of bob
      const signature = await signCreditsBurnProof(
        owner,
        nftCredits.address,
        createCreditsBurnProof(0n, 0n, [planId]),
      )

      const txHash = await nftCredits.write.burn(
        [bob.account.address, planId as any, balance, 0n, signature],
        {
          account: creditsBurnerWallet.account,
        },
      )
      expect(txHash).to.be.a('string').to.startWith('0x')

      const tx = await publicClient.waitForTransactionReceipt({ hash: txHash })
      expect(tx.status).to.be.a('string').equalIgnoreCase('reverted') // InvalidCreditsBurnProof

      const balanceAfter = await nftCredits.read.balanceOf([bob.account.address, planId as any])
      expect(balanceAfter).to.equal(bobCreditsBalance)
    })

    it("Owner can burn Bob's credits with Bob's approval", async () => {
      const balance = await nftCredits.read.balanceOf([bob.account.address, planId as any])
      expect(balance).to.equal(bobCreditsBalance)

      // Sign the credits burn proof with bob
      const keyspace = 1234n
      const nonce = (await nftCredits.read.nextNonce([bob.account.address, [keyspace]]))[0]
      const signature = await signCreditsBurnProof(
        bob,
        nftCredits.address,
        createCreditsBurnProof(keyspace, nonce, [planId]),
      )

      const txHash = await nftCredits.write.burn(
        [bob.account.address, planId as any, balance, keyspace, signature],
        {
          account: creditsBurnerWallet.account,
        },
      )
      expect(txHash).to.be.a('string').to.startWith('0x')

      const tx = await publicClient.waitForTransactionReceipt({ hash: txHash })
      expect(tx.status).to.be.a('string').equalIgnoreCase('success')

      const balanceAfter = await nftCredits.read.balanceOf([bob.account.address, planId as any])
      expect(balanceAfter).to.equal(balance - 1n)
    })
  })
})
