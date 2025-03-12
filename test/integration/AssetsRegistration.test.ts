import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { ignition } from 'hardhat'
import FullDeploymentModule from '../../ignition/modules/FullDeployment'
import { expect } from 'chai'

var chai = require('chai')
chai.use(require('chai-string'))

describe('IT: AssetsRegistration', function () {
  let contracts: any
  async function deployModuleFixture() {
    return ignition.deploy(FullDeploymentModule)
  }

  before(async () => {
    contracts = await loadFixture(deployModuleFixture)
  })

  it('I can start testing', async () => {
    expect(contracts.nvmConfig.address).to.be.a('string').to.startWith('0x')
    expect(contracts.plansManager.address).to.be.a('string').to.startWith('0x')
    expect(contracts.assetsRegistry.address)
      .to.be.a('string')
      .to.startWith('0x')

    console.log(`NVM Config: ${contracts.nvmConfig.address}`)
    console.log(`Plans Manager: ${contracts.plansManager.address}`)
    console.log(`Assets Registry: ${contracts.assetsRegistry.address}`)
  })
})
