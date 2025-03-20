import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { expect } from 'chai'
import hre from 'hardhat'
import { generateId, getTxParsedLogs } from '../common/utils'
import { FullDeploymentModule } from '../../ignition/modules/FullDeployment'
import { stringToHex } from 'viem'

var chai = require('chai')
chai.use(require('chai-string'))

describe('AgreementsStore', function () {
  async function deployInstance() {
    // Contracts are deployed using the first signer/account by default
    const [owner, governor, userAccount] = await hre.viem.getWalletClients()

    // const agreementsStore = await hre.viem.deployContract(
    //   'AgreementsStore',
    //   [],
    //   {},
    // )
    const { nvmConfig, assetsRegistry, agreementsStore } = await hre.ignition.deploy(
      FullDeploymentModule,
    )
    const publicClient = await hre.viem.getPublicClient()

    return {
      nvmConfig,
      agreementsStore,
      owner,
      governor,
      userAccount,
      publicClient,
    }
  }

  describe('Assets: I can register assets', () => {
    let nvmConfig: any
    let agreementsStore: any
    let owner: any
    let governor: any
    let userAccount: any
    let publicClient: any
    let agreementId: string
    let seed = generateId()
    let did = generateId()
    let planId = generateId()

    before(async () => {
      const config = await loadFixture(deployInstance)

      nvmConfig = config.nvmConfig
      agreementsStore = config.agreementsStore
      owner = config.owner
      governor = config.governor
      userAccount = config.userAccount
      publicClient = config.publicClient

      console.log('owner:', owner.account.address)
      console.log('governor:', governor.account.address)
      console.log('userAccount:', userAccount.account.address)
      // await agreementsStore.write.initialize([owner.account.address], {
      //   account: owner.account,
      // })
    })

    it('I can generate the hash for a DID', async () => {
      agreementId = await agreementsStore.read.hashAgreementId([seed, owner.account.address])
      console.log(`agreement hash: ${agreementId}`)
      expect(agreementId).to.be.a('string')
      expect(agreementId).startsWith('0x')
    })

    it('I can not find a agreementId on-chain that doesnt exist', async () => {
      const agreement = await agreementsStore.read.getAgreement([agreementId])
      expect(agreement.lastUpdated).to.equal(0n)
    })

    it('I can not register an agreement if Im not a template', async () => {
      const _params = [stringToHex('')]
      await expect(
        agreementsStore.write.register(
          [generateId(), userAccount.account.address, did, planId, [generateId()], [0], _params],
          {
            account: userAccount.account,
          },
        ),
      ).to.be.rejectedWith('OnlyTemplate')
    })

    it('I can generate the hash for a Agreement', async () => {
      await nvmConfig.write.grantTemplate([owner.account.address], {
        account: governor.account,
      })
      const txHash = await agreementsStore.write.register(
        [agreementId, userAccount.account.address, did, planId, [generateId()], [0], []],
        {
          account: owner.account,
        },
      )

      expect(txHash).to.be.a.string
      console.log('txHash:', txHash)
      const logs = await getTxParsedLogs(publicClient, txHash, agreementsStore.abi)
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
