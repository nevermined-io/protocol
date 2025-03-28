import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { expect } from 'chai'
import hre from 'hardhat'
import { generateId, getTxParsedLogs } from '../common/utils'
import { zeroAddress } from 'viem'
import FullDeploymentModule from '../../ignition/modules/FullDeployment'

var chai = require('chai')
chai.use(require('chai-string'))

describe('AssetsRegistry', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployInstance() {
    // Contracts are deployed using the first signer/account by default
    const [owner, userAccount] = await hre.viem.getWalletClients()

    // const assetsRegistry = await hre.viem.deployContract(
    //   'AssetsRegistry',
    //   [],
    //   {},
    // )
    const { nvmConfig, assetsRegistry } = await hre.ignition.deploy(FullDeploymentModule)
    const publicClient = await hre.viem.getPublicClient()

    return {
      assetsRegistry,
      owner,
      userAccount,
      publicClient,
    }
  }

  describe('Deployment', function () {
    it('Should deploy and initialize correctly', async function () {
      const { assetsRegistry, owner, userAccount, publicClient } = await loadFixture(deployInstance)
    })
  })

  describe('Assets: I can register assets', () => {
    let assetsRegistry: any
    let owner: any
    let publicClient: any
    let did: string
    let url = 'https://nevermined.io'
    let didSeed = generateId()
    let planId: string

    before(async () => {
      const config = await loadFixture(deployInstance)
      assetsRegistry = config.assetsRegistry
      owner = config.owner
      publicClient = config.publicClient
    })

    it('I can generate the hash for a DID', async () => {
      did = await assetsRegistry.read.hashDID([didSeed, owner.account.address])
      console.log(`did hash: ${did}`)
      expect(did).to.be.a('string')
      expect(did).startsWith('0x')
    })

    it('I can not find a DID on-chain that doesnt exist', async () => {
      const asset = await assetsRegistry.read.getAsset([did])
      expect(asset.lastUpdated).to.equal(0n)
    })

    it('I can generate the hash for a Plan', async () => {
      const txHash = await assetsRegistry.write.register([didSeed, url, [generateId()]], {
        account: owner.account,
      })

      expect(txHash).to.be.a.string
      console.log('txHash:', txHash)
      const logs = await getTxParsedLogs(publicClient, txHash, assetsRegistry.abi)
      expect(logs.length).to.be.equal(1)
      expect(logs[0].eventName).to.equalIgnoreCase('AssetRegistered')
    })

    it('I can find the asset via DID on-chain because it was registered', async () => {
      const asset = await assetsRegistry.read.getAsset([did])
      console.log('Asset:', asset)
      expect(asset.lastUpdated > 0n).to.be.true
    })

    it('I can not register an asset without plans', async () => {
      await expect(
        assetsRegistry.write.register([generateId(), url, []], {
          account: owner.account,
        }),
      ).to.be.rejectedWith('NotPlansAttached')
    })
  })

  describe('Plans: I can register plans', () => {
    let owner: any
    let assetsRegistry: any
    let publicClient: any
    let did: string
    let planId: string

    let priceConfig = {
      priceType: 0, // Means Fixed Price
      tokenAddress: zeroAddress,
      amounts: [1000, 2000],
      receivers: [
        '0x04005BBD24EC13D5920aD8845C55496A4C24c466',
        '0x9Aa6E515c64fC46FC8B20bA1Ca7f9B26ff404548',
      ],
      contractAddress: zeroAddress,
    }
    const creditsConfig = {
      creditsType: 1, // Means Fixed Credits
      redemptionType: 2, // ROLE AND OWNER can redeem credits
      durationSecs: 0,
      amount: 100,
      minAmount: 1,
      maxAmount: 1,
    }
    const nftAddress = zeroAddress

    before(async () => {
      const config = await loadFixture(deployInstance)

      assetsRegistry = config.assetsRegistry
      owner = config.owner
      publicClient = config.publicClient
    })

    it('I can generate the hash for a Plan', async () => {
      planId = await assetsRegistry.read.hashPlanId([
        priceConfig,
        creditsConfig,
        nftAddress,
        owner.account.address,
      ])
      console.log(`planId hash: ${planId}`)
      expect(planId).to.be.a('string')
      expect(planId).startsWith('0x')
    })

    it('I can not find a planId on-chain that doesnt exist', async () => {
      const planData = await assetsRegistry.read.getPlan([planId])
      expect(planData.lastUpdated).to.equal(0n)
    })

    it('I can not register a plan without fees included', async () => {
      await expect(
        assetsRegistry.write.createPlan([priceConfig, creditsConfig, nftAddress], {
          account: owner.account,
        }),
      ).to.be.rejectedWith('NeverminedFeesNotIncluded')
    })

    it('I can check if payments distribution are included', async () => {
      const areFeesIncluded = await assetsRegistry.read.areNeverminedFeesIncluded([
        priceConfig.amounts,
        priceConfig.receivers,
      ])
      expect(areFeesIncluded).to.be.false
    })

    it('I can include the fees to a plan', async () => {
      console.log('FEES BEFORE: ', priceConfig.amounts, priceConfig.receivers)

      const result = await assetsRegistry.read.addFeesToPaymentsDistribution([
        priceConfig.amounts,
        priceConfig.receivers,
      ])
      const [_amounts, _receivers] = result
      console.log(result)
      console.log('FEES AFTER: ', _amounts, _receivers)

      const areFeesIncluded = await assetsRegistry.read.areNeverminedFeesIncluded([
        _amounts,
        _receivers,
      ])

      expect(areFeesIncluded).to.be.true
      priceConfig.amounts = _amounts
      priceConfig.receivers = _receivers
    })

    it('I can register a plan with fees included', async () => {
      const txHash = await assetsRegistry.write.createPlan(
        [priceConfig, creditsConfig, nftAddress],
        { account: owner.account },
      )

      expect(txHash).to.be.a.string
      console.log('txHash:', txHash)
      const logs = await getTxParsedLogs(publicClient, txHash, assetsRegistry.abi)
      expect(logs.length).to.be.equal(1)
      expect(logs[0].eventName).to.equalIgnoreCase('PlanRegistered')
      planId = logs[0].args.planId
    })

    it('I can find a planId on-chain because it was registered', async () => {
      const planData = await assetsRegistry.read.getPlan([planId])
      console.log('planData:', planData)
      expect(planData.lastUpdated > 0n).to.be.true
    })

    it('I can register an asset with a plan at once', async () => {
      const txHash = await assetsRegistry.write.registerAssetAndPlan(
        [generateId(), 'https://nevermined.io', priceConfig, creditsConfig, nftAddress],
        { account: owner.account },
      )

      expect(txHash).to.be.a.string
      console.log('txHash:', txHash)
      const logs = await getTxParsedLogs(publicClient, txHash, assetsRegistry.abi)
      expect(logs.length).to.be.greaterThanOrEqual(1)
      did = logs[0].args.did
    })
    it('I can find a planId on-chain because it was registered', async () => {
      const asset = await assetsRegistry.read.getAsset([did])
      planId = asset.plans[0]
      expect(planId).to.be.a('string')
      const plan = await assetsRegistry.read.getPlan([planId])
      console.log('Plan:', plan)
      expect(plan.lastUpdated > 0n).to.be.true
    })
  })
})
