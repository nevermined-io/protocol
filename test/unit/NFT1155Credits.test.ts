import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { expect } from 'chai'
import hre from 'hardhat'
import { getTxParsedLogs } from '../common/utils'
import { zeroAddress } from 'viem'
import FullDeploymentModule from '../../ignition/modules/FullDeployment'

var chai = require('chai')
chai.use(require('chai-string'))

describe('NFT1155Credits', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployInstance() {
    // Contracts are deployed using the first signer/account by default
    const [owner, minter, burner, unauthorized] = await hre.viem.getWalletClients()

    const { nvmConfig, nftCredits } = await hre.ignition.deploy(FullDeploymentModule)
    const publicClient = await hre.viem.getPublicClient()

    // Get the role constants
    const CREDITS_MINTER_ROLE = await nftCredits.read.CREDITS_MINTER_ROLE()
    const CREDITS_BURNER_ROLE = await nftCredits.read.CREDITS_BURNER_ROLE()

    // Grant roles for testing
    await nvmConfig.write.grantRole([CREDITS_MINTER_ROLE, minter.account.address], {
      account: owner.account,
    })
    await nvmConfig.write.grantRole([CREDITS_BURNER_ROLE, burner.account.address], {
      account: owner.account,
    })

    return {
      nftCredits,
      nvmConfig,
      owner,
      minter,
      burner,
      unauthorized,
      publicClient,
      CREDITS_MINTER_ROLE,
      CREDITS_BURNER_ROLE,
    }
  }

  describe('Deployment', function () {
    it('Should deploy and initialize correctly', async function () {
      const { nftCredits, nvmConfig } = await loadFixture(deployInstance)

      // Verify the contract is initialized with the correct config
      expect(await nftCredits.address)
        .to.be.a('string')
        .to.startWith('0x')
    })
  })

  describe('Role-based access control for minting', function () {
    it('Account with CREDITS_MINTER_ROLE can mint credits', async function () {
      const { nftCredits, minter, unauthorized } = await loadFixture(deployInstance)

      const tokenId = 1n
      const amount = 100n

      // Mint credits as authorized minter
      const txHash = await nftCredits.write.mint(
        [unauthorized.account.address, tokenId, amount, '0x'],
        { account: minter.account },
      )

      expect(txHash).to.be.a('string')

      // Check balance was updated correctly
      const balance = await nftCredits.read.balanceOf([unauthorized.account.address, tokenId])

      expect(balance).to.equal(amount)
    })

    it('Account without CREDITS_MINTER_ROLE cannot mint credits', async function () {
      const { nftCredits, unauthorized } = await loadFixture(deployInstance)

      const tokenId = 1n
      const amount = 100n

      // Try to mint as unauthorized account
      await expect(
        nftCredits.write.mint([unauthorized.account.address, tokenId, amount, '0x'], {
          account: unauthorized.account,
        }),
      ).to.be.rejectedWith('InvalidRole')
    })

    it('Account with CREDITS_MINTER_ROLE can mint batch credits', async function () {
      const { nftCredits, minter, unauthorized } = await loadFixture(deployInstance)

      const tokenIds = [1n, 2n]
      const amounts = [100n, 200n]

      // Mint batch credits as authorized minter
      const txHash = await nftCredits.write.mintBatch(
        [unauthorized.account.address, tokenIds, amounts, '0x'],
        { account: minter.account },
      )

      expect(txHash).to.be.a('string')

      // Check balances were updated correctly
      const balance1 = await nftCredits.read.balanceOf([unauthorized.account.address, tokenIds[0]])

      const balance2 = await nftCredits.read.balanceOf([unauthorized.account.address, tokenIds[1]])

      expect(balance1).to.equal(amounts[0])
      expect(balance2).to.equal(amounts[1])
    })

    it('Account without CREDITS_MINTER_ROLE cannot mint batch credits', async function () {
      const { nftCredits, unauthorized } = await loadFixture(deployInstance)

      const tokenIds = [1n, 2n]
      const amounts = [100n, 200n]

      // Try to mint batch as unauthorized account
      await expect(
        nftCredits.write.mintBatch([unauthorized.account.address, tokenIds, amounts, '0x'], {
          account: unauthorized.account,
        }),
      ).to.be.rejectedWith('InvalidRole')
    })
  })

  describe('Role-based access control for burning', function () {
    it('Account with CREDITS_BURNER_ROLE can burn credits', async function () {
      const { nftCredits, minter, burner, unauthorized } = await loadFixture(deployInstance)

      const tokenId = 1n
      const mintAmount = 100n
      const burnAmount = 50n

      // First mint some credits to burn
      await nftCredits.write.mint([unauthorized.account.address, tokenId, mintAmount, '0x'], {
        account: minter.account,
      })

      // Check initial balance
      const initialBalance = await nftCredits.read.balanceOf([
        unauthorized.account.address,
        tokenId,
      ])

      expect(initialBalance).to.equal(mintAmount)

      // Burn credits as authorized burner
      const txHash = await nftCredits.write.burn(
        [unauthorized.account.address, tokenId, burnAmount],
        { account: burner.account },
      )

      expect(txHash).to.be.a('string')

      // Check balance was updated correctly after burn
      const finalBalance = await nftCredits.read.balanceOf([unauthorized.account.address, tokenId])

      expect(finalBalance).to.equal(mintAmount - burnAmount)
    })

    it('Account without CREDITS_BURNER_ROLE cannot burn credits', async function () {
      const { nftCredits, minter, unauthorized } = await loadFixture(deployInstance)

      const tokenId = 1n
      const mintAmount = 100n
      const burnAmount = 50n

      // First mint some credits
      await nftCredits.write.mint([unauthorized.account.address, tokenId, mintAmount, '0x'], {
        account: minter.account,
      })

      // Try to burn as unauthorized account
      await expect(
        nftCredits.write.burn([unauthorized.account.address, tokenId, burnAmount], {
          account: unauthorized.account,
        }),
      ).to.be.rejectedWith('InvalidRole')

      // Verify balance hasn't changed
      const balance = await nftCredits.read.balanceOf([unauthorized.account.address, tokenId])

      expect(balance).to.equal(mintAmount)
    })

    it('Account with CREDITS_BURNER_ROLE can burn batch credits', async function () {
      const { nftCredits, minter, burner, unauthorized } = await loadFixture(deployInstance)

      const tokenIds = [1n, 2n]
      const mintAmounts = [100n, 200n]
      const burnAmounts = [50n, 100n]

      // First mint some batch credits to burn
      await nftCredits.write.mintBatch(
        [unauthorized.account.address, tokenIds, mintAmounts, '0x'],
        { account: minter.account },
      )

      // Check initial balances
      const initialBalance1 = await nftCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[0],
      ])

      const initialBalance2 = await nftCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[1],
      ])

      expect(initialBalance1).to.equal(mintAmounts[0])
      expect(initialBalance2).to.equal(mintAmounts[1])

      // Burn batch credits as authorized burner
      const txHash = await nftCredits.write.burnBatch(
        [unauthorized.account.address, tokenIds, burnAmounts],
        { account: burner.account },
      )

      expect(txHash).to.be.a('string')

      // Check balances were updated correctly after burn
      const finalBalance1 = await nftCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[0],
      ])

      const finalBalance2 = await nftCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[1],
      ])

      expect(finalBalance1).to.equal(mintAmounts[0] - burnAmounts[0])
      expect(finalBalance2).to.equal(mintAmounts[1] - burnAmounts[1])
    })

    it('Account without CREDITS_BURNER_ROLE cannot burn batch credits', async function () {
      const { nftCredits, minter, unauthorized } = await loadFixture(deployInstance)

      const tokenIds = [1n, 2n]
      const mintAmounts = [100n, 200n]
      const burnAmounts = [50n, 100n]

      // First mint some batch credits
      await nftCredits.write.mintBatch(
        [unauthorized.account.address, tokenIds, mintAmounts, '0x'],
        { account: minter.account },
      )

      // Try to burn batch as unauthorized account
      await expect(
        nftCredits.write.burnBatch([unauthorized.account.address, tokenIds, burnAmounts], {
          account: unauthorized.account,
        }),
      ).to.be.rejectedWith('InvalidRole')

      // Verify balances haven't changed
      const balance1 = await nftCredits.read.balanceOf([unauthorized.account.address, tokenIds[0]])

      const balance2 = await nftCredits.read.balanceOf([unauthorized.account.address, tokenIds[1]])

      expect(balance1).to.equal(mintAmounts[0])
      expect(balance2).to.equal(mintAmounts[1])
    })
  })
})
