import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import chai, { expect } from 'chai'
import hre from 'hardhat'
import { zeroAddress } from 'viem'
import {
  getTxParsedLogs,
  generateId,
  createPriceConfig,
  createCreditsConfig,
  registerAssetAndPlan,
  createAgreement,
} from '../common/utils'
import chaiString from 'chai-string'
import { FoundryTools } from '../common/FoundryTools'
// import FullDeploymentModule from '../../ignition/modules/FullDeployment'

// Configure chai plugins
chai.use(chaiString)

describe('LockPaymentCondition', function () {
  
  // We define a fixture to reuse the same setup in every test.
  async function deployInstance() {
    // Contracts are deployed using the first signer/account by default
    const wallets = await hre.viem.getWalletClients()
    const owner = wallets[0]
    const governor = wallets[1]
    const template = wallets[2]
    const user = wallets[3]

    const foundryTools = new FoundryTools(wallets)
    const { nvmConfig, assetsRegistry, agreementsStore, paymentsVault, lockPaymentCondition } =  
    await foundryTools.connectToInstance(process.env.DEPLOYMENT_ADDRESSES_JSON || 'deployment-latest.json')

    // Deploy full module
    // const { nvmConfig, assetsRegistry, agreementsStore, paymentsVault, lockPaymentCondition } =
    //   await hre.ignition.deploy(FullDeploymentModule)

    // Deploy MockERC20
    const mockERC20 = await foundryTools.deployContract(
      'MockERC20',
      ['Test Token', 'TST'],
      'artifacts/contracts/test/MockERC20.sol/MockERC20.json',
    )

    // Grant template role to the template account
    await nvmConfig.write.grantTemplate([template.account.address], {
      account: governor.account,
    })

    // Grant condition role to the LockPaymentCondition contract
    await nvmConfig.write.grantCondition([lockPaymentCondition.address], {
      account: governor.account,
    })

    // Grant depositor role to the LockPaymentCondition contract in PaymentsVault
    const depositorRole = await paymentsVault.read.DEPOSITOR_ROLE()
    await nvmConfig.write.setParameter([depositorRole, lockPaymentCondition.address], {
      account: governor.account,
    })

    // Mint some tokens to user
    await mockERC20.write.mint([user.account.address, 1000n * 10n ** 18n], {
      account: owner.account,
      chain: (await hre.viem.getPublicClient()).chain
    })

    const publicClient = await hre.viem.getPublicClient()

    return {
      nvmConfig,
      assetsRegistry,
      agreementsStore,
      paymentsVault,
      lockPaymentCondition,
      mockERC20,
      owner,
      governor,
      template,
      user,
      publicClient,
    }
  }

  describe('Deployment', function () {
    it('Should deploy and initialize correctly', async function () {
      const { lockPaymentCondition } = await loadFixture(deployInstance)
      // Verify initialization by checking contract name
      const contractName = await lockPaymentCondition.read.NVM_CONTRACT_NAME()
      expect(contractName).to.equal(await lockPaymentCondition.read.NVM_CONTRACT_NAME())
    })
  })

  describe('Fulfill Method - Native Token', function () {
    let did: `0x${string}`
    let planId: bigint
    let agreementId: `0x${string}`
    let conditionId: `0x${string}`

    beforeEach(async function () {
      const { assetsRegistry, agreementsStore, lockPaymentCondition, owner, user, template } =
        await loadFixture(deployInstance)
      
      const priceConfig = createPriceConfig(zeroAddress, owner.account.address)

      // Register asset and plan
      const assetData = await registerAssetAndPlan(
        assetsRegistry,
        priceConfig,
        createCreditsConfig(),
        owner
      )
      did = assetData.did
      planId = assetData.planId

      // Create agreement
      const agreementData = await createAgreement(
        agreementsStore,
        lockPaymentCondition,
        did,
        planId,
        user,
        template,
      )
      agreementId = agreementData.agreementId
      conditionId = agreementData.conditionId
    })

    it('Should fulfill condition with native token payment', async function () {
      const {
        lockPaymentCondition,
        agreementsStore,
        paymentsVault,
        assetsRegistry,
        template,
        user,
        publicClient,
      } = await loadFixture(deployInstance)

      // Register asset and plan with user as creator
      const assetData = await registerAssetAndPlan(
        assetsRegistry,
        createPriceConfig(zeroAddress, user.account.address),
        createCreditsConfig(),
        user
      )
      // const assetData = await registerAssetAndPlan(
      //   assetsRegistry,
      //   zeroAddress,
      //   user,
      //   user.account.address,
      // )
      const testDid = assetData.did
      const testPlanId = assetData.planId

      // Create agreement
      const agreementData = await createAgreement(
        agreementsStore,
        lockPaymentCondition,
        testDid,
        testPlanId,
        user,
        template,
      )
      const testAgreementId = agreementData.agreementId
      const testConditionId = agreementData.conditionId

      // Get plan to determine payment amount
      const plan = await assetsRegistry.read.getPlan([testPlanId])
      const totalAmount = plan.price.amounts.reduce((a, b) => a + b, 0n)

      // Fulfill condition
      const txHash = await lockPaymentCondition.write.fulfill(
        [testConditionId, testAgreementId, testPlanId, user.account.address],
        { account: template.account, value: totalAmount },
      )

      // Verify condition state
      const conditionState = await agreementsStore.read.getConditionState([
        testAgreementId,
        testConditionId,
      ])
      expect(conditionState).to.equal(2) // Fulfilled

      // Verify vault balance
      const vaultBalance = await paymentsVault.read.getBalanceNativeToken()
      expect(vaultBalance).to.equal(totalAmount)

      // Verify event logs
      const logs = await getTxParsedLogs(publicClient, txHash, agreementsStore.abi)
      expect(logs.length).to.be.greaterThanOrEqual(1)
      expect(logs[0].eventName).to.equalIgnoreCase('ConditionUpdated')
      expect(logs[0].args.agreementId).to.equal(testAgreementId)
      expect(logs[0].args.conditionId).to.equal(testConditionId)
      expect(logs[0].args.state).to.equal(2) // Fulfilled
    })
  })

  describe('Fulfill Method - ERC20 Token', function () {
    let did: `0x${string}`
    let planId: bigint
    let agreementId: `0x${string}`
    let conditionId: `0x${string}`

    beforeEach(async function () {
      const {
        assetsRegistry,
        agreementsStore,
        lockPaymentCondition,
        mockERC20,
        owner,
        user,
        template,
      } = await loadFixture(deployInstance)

      // Register asset and plan with ERC20 token
      const assetData = await registerAssetAndPlan(
        assetsRegistry,
        createPriceConfig(mockERC20.address, owner.account.address),
        createCreditsConfig(),
        owner
      )
      
      did = assetData.did
      planId = assetData.planId

      // Create agreement
      const agreementData = await createAgreement(
        agreementsStore,
        lockPaymentCondition,
        did,
        planId,
        user,
        template,
      )
      agreementId = agreementData.agreementId
      conditionId = agreementData.conditionId
    })

    it('Should fulfill condition with ERC20 token payment', async function () {
      const {
        lockPaymentCondition,
        agreementsStore,
        paymentsVault,
        mockERC20,
        assetsRegistry,
        template,
        user,
        publicClient,
      } = await loadFixture(deployInstance)

      // Register asset and plan with user as creator
      const assetData = await registerAssetAndPlan(
        assetsRegistry,
        mockERC20.address,
        user,
        user.account.address,
      )
      const testDid = assetData.did
      const testPlanId = assetData.planId

      // Create agreement
      const agreementData = await createAgreement(
        agreementsStore,
        lockPaymentCondition,
        testDid,
        testPlanId,
        user,
        template,
      )
      const testAgreementId = agreementData.agreementId
      const testConditionId = agreementData.conditionId

      // Get plan to determine payment amount
      const plan = await assetsRegistry.read.getPlan([testPlanId])
      const totalAmount = plan.price.amounts.reduce((a, b) => a + b, 0n)
      // Mint tokens for user and approve for LockPaymentCondition contract
      await mockERC20.write.mint([user.account.address, totalAmount], {
        account: user.account,
        chain: publicClient.chain
      })
      await mockERC20.write.approve([lockPaymentCondition.address, totalAmount], {
        account: user.account,
        chain: publicClient.chain
      })

      // Fulfill condition
      const txHash = await lockPaymentCondition.write.fulfill(
        [testConditionId, testAgreementId, testPlanId, user.account.address],
        { account: template.account },
      )

      // Verify condition state
      const conditionState = await agreementsStore.read.getConditionState([
        testAgreementId,
        testConditionId,
      ])
      expect(conditionState).to.equal(2) // Fulfilled

      // Verify vault balance
      const vaultBalance = await paymentsVault.read.getBalanceERC20([mockERC20.address])
      expect(vaultBalance).to.equal(totalAmount)

      // Verify event logs
      const logs = await getTxParsedLogs(publicClient, txHash, agreementsStore.abi)
      expect(logs.length).to.be.greaterThanOrEqual(1)
      expect(logs[0].eventName).to.equalIgnoreCase('ConditionUpdated')
      expect(logs[0].args.agreementId).to.equal(testAgreementId)
      expect(logs[0].args.conditionId).to.equal(testConditionId)
      expect(logs[0].args.state).to.equal(2) // Fulfilled
    })
  })

  describe('Error Conditions', function () {
    let did: `0x${string}`
    let planId: bigint
    let agreementId: `0x${string}`
    let conditionId: `0x${string}`

    beforeEach(async function () {
      const { assetsRegistry, agreementsStore, lockPaymentCondition, owner, user, template } =
        await loadFixture(deployInstance)

      // Register asset and plan
      const assetData = await registerAssetAndPlan(
        assetsRegistry, 
        createPriceConfig(zeroAddress, owner.account.address), 
        createCreditsConfig(), 
        owner
      )
      // const assetData = await registerAssetAndPlan(
      //   assetsRegistry,
      //   zeroAddress,
      //   owner,
      //   owner.account.address,
      // )
      did = assetData.did
      planId = assetData.planId

      // Create agreement
      const agreementData = await createAgreement(
        agreementsStore,
        lockPaymentCondition,
        did,
        planId,
        user,
        template,
      )
      agreementId = agreementData.agreementId
      conditionId = agreementData.conditionId
    })

    it('Should reject if caller is not a template', async function () {
      const { lockPaymentCondition, user } = await loadFixture(deployInstance)

      // Try to fulfill condition from non-template account
      await expect(
        lockPaymentCondition.write.fulfill(
          [conditionId, agreementId, planId, user.account.address],
          { account: user.account, value: 100n },
        ),
      ).to.be.rejectedWith('OnlyTemplate')
    })

    it('Should reject if agreement does not exist', async function () {
      const { lockPaymentCondition, template, user } = await loadFixture(deployInstance)

      // Try to fulfill condition with non-existent agreement
      const fakeAgreementId = ('0x' + '1'.repeat(64)) as `0x${string}`

      await expect(
        lockPaymentCondition.write.fulfill(
          [conditionId, fakeAgreementId, planId, user.account.address],
          { account: template.account, value: 100n },
        ),
      ).to.be.rejectedWith('AgreementNotFound')
    })

    it('Should reject if condition does not exist', async function () {
      const { lockPaymentCondition, agreementsStore, assetsRegistry, template, user } =
        await loadFixture(deployInstance)

      // Register asset and plan
      const assetData = await registerAssetAndPlan(
        assetsRegistry,
        zeroAddress,
        user,
        user.account.address,
      )
      const realDid = assetData.did
      const realPlanId = assetData.planId

      // Create agreement with empty condition IDs
      const agreementSeed = generateId()
      const realAgreementId = await agreementsStore.read.hashAgreementId([
        agreementSeed,
        user.account.address,
      ])

      // Register agreement
      await agreementsStore.write.register(
        [realAgreementId, user.account.address, realDid, realPlanId, [], [], []],
        { account: template.account },
      )

      // Generate condition ID
      const contractName = await lockPaymentCondition.read.NVM_CONTRACT_NAME()
      const realConditionId = await lockPaymentCondition.read.hashConditionId([
        realAgreementId,
        contractName,
      ])

      await expect(
        lockPaymentCondition.write.fulfill(
          [realConditionId, realAgreementId, realPlanId, user.account.address],
          { account: template.account, value: 101n },
        ),
      ).to.be.rejectedWith('ConditionIdNotFound')
    })

    it('Should reject if payment amount is incorrect', async function () {
      const { lockPaymentCondition, agreementsStore, assetsRegistry, template, user } =
        await loadFixture(deployInstance)

      // Register asset and plan
      const assetData = await registerAssetAndPlan(
        assetsRegistry,
        zeroAddress,
        user,
        user.account.address,
      )
      const realDid = assetData.did
      const realPlanId = assetData.planId

      // Create agreement with empty condition IDs
      const agreementSeed = generateId()
      const realAgreementId = await agreementsStore.read.hashAgreementId([
        agreementSeed,
        user.account.address,
      ])

      // Register agreement
      await agreementsStore.write.register(
        [realAgreementId, user.account.address, realDid, realPlanId, [], [], []],
        { account: template.account },
      )

      // Generate condition ID
      const contractName = await lockPaymentCondition.read.NVM_CONTRACT_NAME()
      const realConditionId = await lockPaymentCondition.read.hashConditionId([
        realAgreementId,
        contractName,
      ])

      // Get plan to determine payment amount
      const plan = await assetsRegistry.read.getPlan([realPlanId])
      const totalAmount = plan.price.amounts.reduce((a, b) => a + b, 0n)

      // Try to fulfill condition with incorrect payment amount
      await expect(
        lockPaymentCondition.write.fulfill(
          [realConditionId, realAgreementId, realPlanId, user.account.address],
          { account: template.account, value: totalAmount - 1n },
        ),
      ).to.be.rejectedWith('InvalidTransactionAmount')
    })

    it('Should reject unsupported price types', async function () {
      const { lockPaymentCondition, assetsRegistry, agreementsStore, template, owner, user } =
        await loadFixture(deployInstance)

      // Create price config with FIXED_FIAT_PRICE
      const priceConfig: any = {
        priceType: 1, // FIXED_FIAT_PRICE
        tokenAddress: zeroAddress,
        amounts: [100n],
        receivers: [owner.account.address],
        contractAddress: zeroAddress,
      }

      // Add Nevermined fees
      const result = await assetsRegistry.read.addFeesToPaymentsDistribution([
        priceConfig.amounts,
        priceConfig.receivers,
      ])
      priceConfig.amounts = [...result[0]]
      priceConfig.receivers = [...result[1]]

      // Register asset and plan with FIXED_FIAT_PRICE
      const didSeed = generateId()
      const newDid = await assetsRegistry.read.hashDID([didSeed, owner.account.address])

      // Create credits config
      const creditsConfig = createCreditsConfig()

      // Register asset and plan
      await assetsRegistry.write.registerAssetAndPlan(
        [didSeed, 'https://nevermined.io', priceConfig, creditsConfig, zeroAddress],
        { account: owner.account },
      )

      // Get plan ID
      const asset = await assetsRegistry.read.getAsset([newDid])
      const newPlanId = asset.plans[0]

      // Create agreement
      const agreementSeed = generateId()
      const newAgreementId = await agreementsStore.read.hashAgreementId([
        agreementSeed,
        user.account.address,
      ])

      // Register agreement
      await agreementsStore.write.register(
        [newAgreementId, user.account.address, newDid, newPlanId, [], [], []],
        { account: template.account },
      )

      // Generate condition ID
      const contractName = await lockPaymentCondition.read.NVM_CONTRACT_NAME()
      const newConditionId = await lockPaymentCondition.read.hashConditionId([
        newAgreementId,
        contractName,
      ])

      // Try to fulfill condition with FIXED_FIAT_PRICE
      await expect(
        lockPaymentCondition.write.fulfill(
          [newConditionId, newAgreementId, newPlanId, user.account.address],
          { account: template.account },
        ),
      ).to.be.rejectedWith('UnsupportedPriceTypeOption')
    })
  })
})
