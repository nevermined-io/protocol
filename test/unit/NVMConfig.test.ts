import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { expect } from 'chai'
import hre from 'hardhat'
import { toHex, zeroAddress } from 'viem'
import { getTxParsedLogs, sha3 } from '../common/utils'
import { NVMConfigModule } from '../../ignition/modules/FullDeployment'

var chai = require('chai')
chai.use(require('chai-string'))

describe('NVMConfig', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployInstance() {
    // Contracts are deployed using the first signer/account by default
    const [owner, governor] = await hre.viem.getWalletClients()

    // const nvmConfig = await hre.viem.deployContract('NVMConfig', [], {})
    const { nvmConfig } = await hre.ignition.deploy(NVMConfigModule)
    const publicClient = await hre.viem.getPublicClient()
    // FullDeploymentModule
    return {
      nvmConfig,
      owner,
      governor,
      publicClient,
    }
  }

  describe('Deployment', function () {
    it('Should deploy and initialize correctly', async function () {
      const { nvmConfig, owner, governor, publicClient } = await loadFixture(deployInstance)
      // const hash = await nvmConfig.write.initialize(
      //   [owner.account.address, governor.account.address],
      //   { account: owner.account },
      // )
      // console.log(`txHash: ${hash}`)
      // expect(hash).to.be.a('string')

      // await publicClient.waitForTransactionReceipt({ hash }).then((receipt) => {
      //   expect(receipt.status).to.equal('success')
      // })
    })
  })

  describe('Fees: We can apply some configuration', () => {
    let nvmConfig: any
    let owner: any
    let governor: any
    let publicClient: any

    before(async () => {
      const config = await loadFixture(deployInstance)
      nvmConfig = config.nvmConfig
      owner = config.owner
      governor = config.governor
      publicClient = config.publicClient
    })

    it('Fees can be changed by a governor account', async () => {
      const txHash = await nvmConfig.write.setNetworkFees([100n, governor.account.address], {
        account: governor.account,
      })
      expect(txHash).to.be.a.string

      expect(await nvmConfig.read.getNetworkFee()).to.equal(100n)
      expect(await nvmConfig.read.getFeeReceiver()).to.equalIgnoreCase(governor.account.address)

      console.log('txHash:', txHash)
      const logs = await getTxParsedLogs(publicClient, txHash, nvmConfig.abi)
      expect(logs.length).to.be.greaterThanOrEqual(2)
      expect(logs[0].eventName).to.equalIgnoreCase('NeverminedConfigChange')
    })

    it('Configuration can not be changed by a not granted account', async () => {
      const [, , another] = await hre.viem.getWalletClients()
      await expect(
        nvmConfig.write.setNetworkFees([100n, another.account.address], {
          account: another.account,
        }),
      ).to.be.rejectedWith('OnlyGovernor')
    })

    it('Network fees can not have an invalid value', async () => {
      await expect(
        nvmConfig.write.setNetworkFees([9900000n, governor.account.address], {
          account: governor.account,
        }),
      ).to.be.rejectedWith('InvalidNetworkFee')
    })

    it('Network fees receiver can not be the zero address', async () => {
      await expect(
        nvmConfig.write.setNetworkFees([100n, zeroAddress], {
          account: governor.account,
        }),
      ).to.be.rejectedWith('InvalidFeeReceiver')
    })
  })

  describe('Params: We can apply some configuration', () => {
    let nvmConfig: any
    let owner: any
    let governor: any
    let publicClient: any
    let paramName = sha3('myparam')
    let paramValue = toHex('myvalue')

    before(async () => {
      const config = await loadFixture(deployInstance)

      nvmConfig = config.nvmConfig
      owner = config.owner
      governor = config.governor
      publicClient = config.publicClient
    })

    it('Params can be set by a governor account', async () => {
      console.log('paramName:', paramName)
      console.log('paramValue:', paramValue)
      const txHash = await nvmConfig.write.setParameter([paramName, paramValue], {
        account: governor.account,
      })
      expect(txHash).to.be.a.string
      const _value = await nvmConfig.read.getParameter([paramName])
      expect(_value[0]).to.equal(paramValue)
      expect(_value[1]).to.be.true

      console.log('txHash:', txHash)
      const logs = await getTxParsedLogs(publicClient, txHash, nvmConfig.abi)
      expect(logs.length).to.be.greaterThanOrEqual(1)
      // console.log('Parsed Logs', logs)
      expect(logs[0].eventName).to.equalIgnoreCase('NeverminedConfigChange')
    })

    it('Configuration can not be changed by a not granted account', async () => {
      const [, , another] = await hre.viem.getWalletClients()
      await expect(
        nvmConfig.write.setParameter([paramName, paramValue], {
          account: another.account,
        }),
      ).to.be.rejectedWith('OnlyGovernor')
    })
  })

  describe('Only the owner can grant Governor permissions', () => {
    let config: any
    let newGovernor: any

    before(async () => {
      config = await loadFixture(deployInstance)

      const [, , anotherAccount] = await hre.viem.getWalletClients()
      newGovernor = anotherAccount
    })
    it('The owner grants governor permissions', async () => {
      const governorAddress = newGovernor.account.address
      const txHash = await config.nvmConfig.write.grantGovernor([governorAddress], {
        account: config.owner.account,
      })

      const isGovernor = await config.nvmConfig.read.isGovernor([governorAddress])
      expect(isGovernor).to.be.true

      console.log('txHash:', txHash)
      const logs = await getTxParsedLogs(config.publicClient, txHash, config.nvmConfig.abi)
      expect(logs.length).to.be.greaterThanOrEqual(2)
      expect(logs[1].eventName).to.equalIgnoreCase('ConfigPermissionsChange')
    })

    it('The governor can not grant governor permissions', async () => {
      await expect(
        config.nvmConfig.write.grantGovernor([zeroAddress], {
          account: config.governor.account,
        }),
      ).to.be.rejectedWith('OnlyOwner')
    })

    it('The governor can not revoke governor permissions', async () => {
      await expect(
        config.nvmConfig.write.revokeGovernor([config.owner.account.address], {
          account: config.governor.account,
        }),
      ).to.be.rejectedWith('OnlyOwner')
    })

    it('The owner revokes governor permissions', async () => {
      const governorAddress = newGovernor.account.address
      await config.nvmConfig.write.revokeGovernor([governorAddress], {
        account: config.owner.account,
      })

      const isGovernor = await config.nvmConfig.read.isGovernor([governorAddress])
      expect(isGovernor).to.be.false
    })
  })
})
