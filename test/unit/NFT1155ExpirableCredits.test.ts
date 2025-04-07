import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { expect } from 'chai'
import hre from 'hardhat'
import { registerPlan } from '../common/utils'
import { parseAbi, zeroAddress } from 'viem'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import FullDeploymentModule from '../../ignition/modules/FullDeployment'

var chai = require('chai')
chai.use(require('chai-string'))

describe('NFT1155ExpirableCredits', function () {
  const mintAbi = parseAbi([
    'function mint(address _to, uint256 _id, uint256 _value, uint256 _secsDuration, bytes _data)',
  ])
  const mintBatchAbi = parseAbi([
    'function mintBatch(address _to, uint256[] _ids, uint256[] _values, uint256[] _secsDurations, bytes _data)',
  ])

  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployInstance() {
    // Contracts are deployed using the first signer/account by default
    const [owner, minter, burner, unauthorized] = await hre.viem.getWalletClients()

    // Get the NVMConfig from the FullDeploymentModule
    const { nvmConfig, assetsRegistry } = await hre.ignition.deploy(FullDeploymentModule)

    // Deploy NFT1155ExpirableCredits directly since it's not in the FullDeploymentModule
    const nftExpirableCredits = await hre.viem.deployContract('NFT1155ExpirableCredits')

    // Initialize the contract
    await nftExpirableCredits.write.initialize([
      nvmConfig.address,
      assetsRegistry.address,
      'Nevermined Expirable Credits',
      'NVMEC',
    ])

    const publicClient = await hre.viem.getPublicClient()

    // Get the role constants
    const CREDITS_MINTER_ROLE = await nftExpirableCredits.read.CREDITS_MINTER_ROLE()
    const CREDITS_BURNER_ROLE = await nftExpirableCredits.read.CREDITS_BURNER_ROLE()

    // Grant roles for testing
    await nvmConfig.write.grantRole([CREDITS_MINTER_ROLE, minter.account.address], {
      account: owner.account,
    })
    await nvmConfig.write.grantRole([CREDITS_BURNER_ROLE, burner.account.address], {
      account: owner.account,
    })

    const priceConfig = {
      priceType: 0, // FIXED_PRICE
      tokenAddress: zeroAddress,
      amounts: [100n],
      receivers: [owner.account.address],
      contractAddress: zeroAddress,
    }
    const creditsConfig = {
      creditsType: 0, // EXPIRABLE
      redemptionType: 0, // ONLY_GLOBAL_ROLE
      durationSecs: 10n, // 10 secs
      amount: 1n,
      minAmount: 1n,
      maxAmount: 1n,
    }
    const planId = await registerPlan(
      assetsRegistry,
      owner,
      priceConfig,
      creditsConfig,
      nftExpirableCredits.address,
    )

    const priceConfig2 = { ...priceConfig }
    const creditsConfig2 = { ...creditsConfig, amount: 200n, minAmount: 2n }
    const planId2 = await registerPlan(
      assetsRegistry,
      owner,
      priceConfig2,
      creditsConfig2,
      nftExpirableCredits.address,
    )

    return {
      nftExpirableCredits,
      nvmConfig,
      owner,
      minter,
      burner,
      unauthorized,
      planId,
      planId2,
      priceConfig,
      creditsConfig,
      priceConfig2,
      creditsConfig2,
      publicClient,
      CREDITS_MINTER_ROLE,
      CREDITS_BURNER_ROLE,
    }
  }

  describe('Deployment', function () {
    it('Should deploy and initialize correctly', async function () {
      const { nftExpirableCredits } = await loadFixture(deployInstance)

      // Verify the contract is initialized with the correct config
      expect(await nftExpirableCredits.address)
        .to.be.a('string')
        .to.startWith('0x')
    })
  })

  describe('Role-based access control for minting', function () {
    it('Account with CREDITS_MINTER_ROLE can mint credits', async function () {
      const { nftExpirableCredits, minter, unauthorized, planId, creditsConfig } =
        await loadFixture(deployInstance)

      const amount = creditsConfig.amount

      // Mint credits as authorized minter
      const txHash = await nftExpirableCredits.write.mint(
        [unauthorized.account.address, planId, amount, '0x'],
        { account: minter.account },
      )

      expect(txHash).to.be.a('string')

      // Check balance was updated correctly
      const balance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        planId,
      ])

      expect(balance).to.equal(amount)
    })

    it('Account without CREDITS_MINTER_ROLE cannot mint credits', async function () {
      const { nftExpirableCredits, unauthorized, planId, creditsConfig } =
        await loadFixture(deployInstance)

      const amount = creditsConfig.amount

      // Try to mint as unauthorized account
      await expect(
        nftExpirableCredits.write.mint([unauthorized.account.address, planId, amount, '0x'], {
          account: unauthorized.account,
        }),
      ).to.be.rejectedWith('InvalidRole')
    })

    it('Account with CREDITS_MINTER_ROLE can mint batch credits', async function () {
      const {
        nftExpirableCredits,
        minter,
        unauthorized,
        planId,
        planId2,
        creditsConfig,
        creditsConfig2,
      } = await loadFixture(deployInstance)

      const tokenIds = [planId, planId2]
      const amounts = [creditsConfig.amount, creditsConfig2.amount]

      // Mint batch credits as authorized minter
      const txHash = await nftExpirableCredits.write.mintBatch(
        [unauthorized.account.address, tokenIds, amounts, '0x'],
        { account: minter.account },
      )

      expect(txHash).to.be.a('string')

      // Check balances were updated correctly
      const balance1 = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[0],
      ])

      const balance2 = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[1],
      ])

      expect(balance1).to.equal(amounts[0])
      expect(balance2).to.equal(amounts[1])
    })

    it('Account without CREDITS_MINTER_ROLE cannot mint batch credits', async function () {
      const { nftExpirableCredits, unauthorized, planId, planId2, creditsConfig, creditsConfig2 } =
        await loadFixture(deployInstance)

      const tokenIds = [planId, planId2]
      const amounts = [creditsConfig.amount, creditsConfig2.amount]

      // Try to mint batch as unauthorized account
      await expect(
        nftExpirableCredits.write.mintBatch(
          [unauthorized.account.address, tokenIds, amounts, '0x'],
          { account: unauthorized.account },
        ),
      ).to.be.rejectedWith('InvalidRole')
    })
  })

  describe('Role-based access control for burning', function () {
    it('Account with CREDITS_BURNER_ROLE can burn credits', async function () {
      const { nftExpirableCredits, minter, burner, unauthorized, planId, creditsConfig } =
        await loadFixture(deployInstance)

      const mintAmount = creditsConfig.amount
      const burnAmount = creditsConfig.minAmount

      // First mint some credits to burn
      await nftExpirableCredits.write.mint(
        [unauthorized.account.address, planId, mintAmount, '0x'],
        { account: minter.account },
      )

      // Check initial balance
      const initialBalance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        planId,
      ])

      expect(initialBalance).to.equal(mintAmount)

      // Burn credits as authorized burner
      const txHash = await nftExpirableCredits.write.burn(
        [unauthorized.account.address, planId, burnAmount],
        { account: burner.account },
      )

      expect(txHash).to.be.a('string')

      // Check balance was updated correctly after burn
      const finalBalance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        planId,
      ])

      expect(finalBalance).to.equal(mintAmount - burnAmount)
    })

    it('Account without CREDITS_BURNER_ROLE cannot burn credits', async function () {
      const { nftExpirableCredits, minter, unauthorized, planId, creditsConfig } =
        await loadFixture(deployInstance)

      const mintAmount = creditsConfig.amount
      const burnAmount = creditsConfig.minAmount

      // First mint some credits
      await nftExpirableCredits.write.mint(
        [unauthorized.account.address, planId, mintAmount, '0x'],
        { account: minter.account },
      )

      // Try to burn as unauthorized account
      await expect(
        nftExpirableCredits.write.burn([unauthorized.account.address, planId, burnAmount], {
          account: unauthorized.account,
        }),
      ).to.be.rejectedWith('InvalidRole')

      // Verify balance hasn't changed
      const balance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        planId,
      ])

      expect(balance).to.equal(mintAmount)
    })

    it('Account with CREDITS_BURNER_ROLE can burn batch credits', async function () {
      const {
        nftExpirableCredits,
        minter,
        burner,
        unauthorized,
        planId,
        planId2,
        creditsConfig,
        creditsConfig2,
      } = await loadFixture(deployInstance)

      const tokenIds = [planId, planId2]
      const mintAmounts = [creditsConfig.amount, creditsConfig2.amount]
      const burnAmounts = [creditsConfig.minAmount, creditsConfig2.minAmount]

      // First mint some batch credits to burn
      await nftExpirableCredits.write.mintBatch(
        [unauthorized.account.address, tokenIds, mintAmounts, '0x'],
        { account: minter.account },
      )

      // Check initial balances
      const initialBalance1 = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[0],
      ])

      const initialBalance2 = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[1],
      ])

      expect(initialBalance1).to.equal(mintAmounts[0])
      expect(initialBalance2).to.equal(mintAmounts[1])

      // Burn batch credits as authorized burner
      const txHash = await nftExpirableCredits.write.burnBatch(
        [unauthorized.account.address, tokenIds, burnAmounts],
        { account: burner.account },
      )

      expect(txHash).to.be.a('string')

      // Check balances were updated correctly after burn
      const finalBalance1 = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[0],
      ])

      const finalBalance2 = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[1],
      ])

      expect(finalBalance1).to.equal(mintAmounts[0] - burnAmounts[0])
      expect(finalBalance2).to.equal(mintAmounts[1] - burnAmounts[1])
    })

    it('Account without CREDITS_BURNER_ROLE cannot burn batch credits', async function () {
      const {
        nftExpirableCredits,
        minter,
        unauthorized,
        planId,
        planId2,
        creditsConfig,
        creditsConfig2,
      } = await loadFixture(deployInstance)

      const tokenIds = [planId, planId2]
      const mintAmounts = [creditsConfig.amount, creditsConfig2.amount]
      const burnAmounts = [creditsConfig.minAmount, creditsConfig2.minAmount]

      // First mint some batch credits
      await nftExpirableCredits.write.mintBatch(
        [unauthorized.account.address, tokenIds, mintAmounts, '0x'],
        { account: minter.account },
      )

      // Try to burn batch as unauthorized account
      await expect(
        nftExpirableCredits.write.burnBatch([unauthorized.account.address, tokenIds, burnAmounts], {
          account: unauthorized.account,
        }),
      ).to.be.rejectedWith('InvalidRole')

      // Verify balances haven't changed
      const balance1 = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[0],
      ])

      const balance2 = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[1],
      ])

      expect(balance1).to.equal(mintAmounts[0])
      expect(balance2).to.equal(mintAmounts[1])
    })
  })

  describe('Credit expiration', function () {
    it('Credits minted with expiration should expire after the specified time', async function () {
      const { nftExpirableCredits, minter, unauthorized, planId, creditsConfig } =
        await loadFixture(deployInstance)

      const amount = creditsConfig.amount
      const expirationSecs = creditsConfig.durationSecs // 10 seconds expiration

      // Mint credits with expiration as authorized minter
      await nftExpirableCredits.write.mint(
        [unauthorized.account.address, planId, amount, expirationSecs, '0x'],
        {
          abi: mintAbi,
          account: minter.account,
          functionName: 'mint',
        },
      )

      // Check initial balance
      const initialBalance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        planId,
      ])

      expect(initialBalance).to.equal(amount)

      // Advance time by 15 seconds (past expiration)
      await time.increase(15)

      // Check balance after expiration
      const finalBalance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        planId,
      ])

      // Balance should be 0 after expiration
      expect(finalBalance).to.equal(0n)
    })

    it('Credits minted without expiration should not expire', async function () {
      const { nftExpirableCredits, minter, unauthorized, planId, creditsConfig } =
        await loadFixture(deployInstance)

      const amount = creditsConfig.amount
      const expirationSecs = 0n // No expiration

      // Mint credits without expiration as authorized minter
      await nftExpirableCredits.write.mint(
        [unauthorized.account.address, planId, amount, expirationSecs, '0x'],
        {
          abi: mintAbi,
          account: minter.account,
          functionName: 'mint',
        },
      )

      // Check initial balance
      const initialBalance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        planId,
      ])

      expect(initialBalance).to.equal(amount)

      // Advance time by 100 seconds
      await time.increase(100)

      // Check balance after time advance
      const finalBalance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        planId,
      ])

      // Balance should still be the same
      expect(finalBalance).to.equal(amount)
    })

    it('balanceOf should correctly account for mixed expired and non-expired credits', async function () {
      const { nftExpirableCredits, minter, unauthorized, planId, creditsConfig } =
        await loadFixture(deployInstance)

      const expirableAmount = 50n
      const permanentAmount = 100n
      const expirationSecs = 20n // 20 seconds expiration

      // Mint expirable credits
      await nftExpirableCredits.write.mint(
        [unauthorized.account.address, planId, expirableAmount, expirationSecs, '0x'],
        {
          abi: mintAbi,
          account: minter.account,
          functionName: 'mint',
        },
      )

      // Mint permanent credits
      await nftExpirableCredits.write.mint(
        [unauthorized.account.address, planId, permanentAmount, 0n, '0x'],
        {
          abi: mintAbi,
          account: minter.account,
          functionName: 'mint',
        },
      )

      // Check initial balance (should be sum of both)
      const initialBalance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        planId,
      ])

      expect(initialBalance).to.equal(expirableAmount + permanentAmount)

      // Advance time by 30 seconds (past expiration of first batch)
      await time.increase(30)

      // Check balance after partial expiration
      const finalBalance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        planId,
      ])

      // Balance should only include the permanent credits
      expect(finalBalance).to.equal(permanentAmount)
    })

    it('balanceOf should correctly account for multiple expirable credits with different expiration times', async function () {
      const { nftExpirableCredits, minter, unauthorized, planId } =
        await loadFixture(deployInstance)

      const tokenId = planId
      const amount1 = 50n
      const amount2 = 75n
      const amount3 = 100n
      const expiration1 = 10n // 10 seconds
      const expiration2 = 30n // 30 seconds
      const expiration3 = 60n // 60 seconds

      // Mint credits with different expiration times
      await nftExpirableCredits.write.mint(
        [unauthorized.account.address, tokenId, amount1, expiration1, '0x'],
        {
          abi: mintAbi,
          account: minter.account,
          functionName: 'mint',
        },
      )

      await nftExpirableCredits.write.mint(
        [unauthorized.account.address, tokenId, amount2, expiration2, '0x'],
        {
          abi: mintAbi,
          account: minter.account,
          functionName: 'mint',
        },
      )

      await nftExpirableCredits.write.mint(
        [unauthorized.account.address, tokenId, amount3, expiration3, '0x'],
        {
          abi: mintAbi,
          account: minter.account,
          functionName: 'mint',
        },
      )

      // Check initial balance
      const initialBalance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenId,
      ])

      expect(initialBalance).to.equal(amount1 + amount2 + amount3)

      // Advance time by 15 seconds (past first expiration)
      await time.increase(15)

      // Check balance after first expiration
      const balanceAfterFirstExpiration = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenId,
      ])

      // Balance should exclude the first batch
      expect(balanceAfterFirstExpiration).to.equal(amount2 + amount3)

      // Advance time by 20 more seconds (past second expiration)
      await time.increase(20)

      // Check balance after second expiration
      const balanceAfterSecondExpiration = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenId,
      ])

      // Balance should only include the third batch
      expect(balanceAfterSecondExpiration).to.equal(amount3)

      // Advance time by 30 more seconds (past all expirations)
      await time.increase(30)

      // Check balance after all expirations
      const finalBalance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenId,
      ])

      // Balance should be 0
      expect(finalBalance).to.equal(0n)
    })

    it('Should correctly handle expiration with batch minting', async function () {
      const {
        nftExpirableCredits,
        minter,
        unauthorized,
        planId,
        planId2,
        creditsConfig,
        creditsConfig2,
      } = await loadFixture(deployInstance)

      const tokenIds = [planId, planId2]
      const amounts = [creditsConfig.amount, creditsConfig2.amount]
      const expirations = [15n, 30n] // Different expiration times

      // Mint batch credits with expiration
      await nftExpirableCredits.write.mintBatch(
        [unauthorized.account.address, tokenIds, amounts, expirations, '0x'],
        {
          abi: mintBatchAbi,
          account: minter.account,
          functionName: 'mintBatch',
        },
      )

      // Check initial balances
      const initialBalance1 = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[0],
      ])

      const initialBalance2 = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[1],
      ])

      expect(initialBalance1).to.equal(amounts[0])
      expect(initialBalance2).to.equal(amounts[1])

      // Advance time by 20 seconds (past first token expiration)
      await time.increase(20)

      // Check balances after first expiration
      const midBalance1 = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[0],
      ])

      const midBalance2 = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[1],
      ])

      // First token should be expired, second should still be valid
      expect(midBalance1).to.equal(0n)
      expect(midBalance2).to.equal(amounts[1])

      // Advance time by 15 more seconds (past second token expiration)
      await time.increase(15)

      // Check final balances
      const finalBalance1 = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[0],
      ])

      const finalBalance2 = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        tokenIds[1],
      ])

      // Both tokens should be expired
      expect(finalBalance1).to.equal(0n)
      expect(finalBalance2).to.equal(0n)
    })

    it('Should correctly handle burning of expirable credits', async function () {
      const { nftExpirableCredits, minter, burner, unauthorized, planId, creditsConfig } =
        await loadFixture(deployInstance)

      const mintAmount = creditsConfig.amount
      const burnAmount = creditsConfig.maxAmount
      const expirationSecs = 30n

      // Mint expirable credits
      await nftExpirableCredits.write.mint(
        [unauthorized.account.address, planId, mintAmount, expirationSecs, '0x'],
        {
          abi: mintAbi,
          account: minter.account,
          functionName: 'mint',
        },
      )

      // Check initial balance
      const initialBalance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        planId,
      ])

      expect(initialBalance).to.equal(mintAmount)

      // Burn some credits
      await nftExpirableCredits.write.burn([unauthorized.account.address, planId, burnAmount], {
        account: burner.account,
      })

      // Check balance after burning
      const balanceAfterBurn = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        planId,
      ])

      expect(balanceAfterBurn).to.equal(mintAmount - burnAmount)

      // Advance time by 15 seconds (half way to expiration)
      await time.increase(15)

      // Balance should still be the same
      const midBalance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        planId,
      ])

      expect(midBalance).to.equal(mintAmount - burnAmount)

      // Advance time by 20 more seconds (past expiration)
      await time.increase(20)

      // Balance should be 0 after expiration
      const finalBalance = await nftExpirableCredits.read.balanceOf([
        unauthorized.account.address,
        planId,
      ])

      expect(finalBalance).to.equal(0n)
    })
  })
})
