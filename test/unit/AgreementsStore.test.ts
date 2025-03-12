import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { expect } from 'chai'
import hre from 'hardhat'
import { generateId, getTxParsedLogs } from '../common/utils'

var chai = require('chai')
chai.use(require('chai-string'))

describe('AgreementsStore', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployInstance() {
    // Contracts are deployed using the first signer/account by default
    const [owner, userAccount] = await hre.viem.getWalletClients()

    const agreementsStore = await hre.viem.deployContract(
      'AgreementsStore',
      [],
      {},
    )

    const publicClient = await hre.viem.getPublicClient()

    return {
      agreementsStore,
      owner,
      userAccount,
      publicClient,
    }
  }

  describe('Deployment', function () {
    it('Should deploy and initialize correctly', async function () {
      const { agreementsStore, owner, userAccount, publicClient } =
        await loadFixture(deployInstance)

      const hash = await agreementsStore.write.initialize(
        [owner.account.address],
        { account: owner.account },
      )
      console.log(`txHash: ${hash}`)
      expect(hash).to.be.a('string')

      await publicClient.waitForTransactionReceipt({ hash }).then((receipt) => {
        expect(receipt.status).to.equal('success')
      })
    })
  })

  describe('Assets: I can register assets', () => {
    let agreementsStore: any
    let owner: any
    let userAccount: any
    let publicClient: any
    let agreementId: string
    let seed = generateId()
    let did = generateId()
    let planId = generateId()

    before(async () => {
      const config = await loadFixture(deployInstance)

      agreementsStore = config.agreementsStore
      owner = config.owner
      userAccount = config.userAccount
      publicClient = config.publicClient

      await agreementsStore.write.initialize([owner.account.address], {
        account: owner.account,
      })
    })

    it('I can generate the hash for a DID', async () => {
      agreementId = await agreementsStore.read.hashAgreementId([
        seed,
        owner.account.address,
      ])
      console.log(`agreement hash: ${agreementId}`)
      expect(agreementId).to.be.a('string')
      expect(agreementId).startsWith('0x')
    })

    it('I can not find a agreementId on-chain that doesnt exist', async () => {
      const agreement = await agreementsStore.read.getAgreement([agreementId])
      expect(agreement.lastUpdated).to.equal(0n)
    })

    it('I can generate the hash for a Agreement', async () => {
      const txHash = await agreementsStore.write.register([seed, did, planId], {
        account: owner.account,
      })

      expect(txHash).to.be.a.string
      console.log('txHash:', txHash)
      const logs = await getTxParsedLogs(
        publicClient,
        txHash,
        agreementsStore.abi,
      )
      expect(logs.length).to.be.equal(1)
      expect(logs[0].eventName).to.equalIgnoreCase('AgreementRegistered')
    })

    it('I can find a agreementId on-chain because it was registered', async () => {
      const agreement = await agreementsStore.read.getAgreement([agreementId])
      console.log('Agreement:', agreement)
      expect(agreement.lastUpdated > 0n).to.be.true
    })
  })
})
