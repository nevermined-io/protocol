import { expect } from 'chai';
import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers';
import hre from 'hardhat';
import { ethers, upgrades } from 'hardhat';
import { zeroAddress, Address } from 'viem';

describe('Contract Upgradeability', function () {
  // Fixture to deploy all the contracts
  async function deployContracts() {
    // Get wallet clients for viem interactions
    const [owner, governor, user1, user2] = await hre.viem.getWalletClients();
    
    // We still need ethers signers for the upgrades plugin
    const [ownerSigner, governorSigner] = await ethers.getSigners();

    // Deploy NVMConfig using ethers for the upgrades plugin
    const NVMConfig = await ethers.getContractFactory('NVMConfig');
    const nvmConfigEthers = await upgrades.deployProxy(
      NVMConfig,
      [owner.account.address, governor.account.address],
      { initializer: 'initialize' }
    );
    await nvmConfigEthers.waitForDeployment();
    
    // Get the viem contract instance for the deployed proxy
    const nvmConfig = await hre.viem.getContractAt(
      'NVMConfig',
      await nvmConfigEthers.getAddress() as Address
    );

    // Deploy AssetsRegistry
    const AssetsRegistry = await ethers.getContractFactory('AssetsRegistry');
    const assetsRegistryEthers = await upgrades.deployProxy(
      AssetsRegistry,
      [await nvmConfigEthers.getAddress()],
      { initializer: 'initialize' }
    );
    await assetsRegistryEthers.waitForDeployment();
    
    // Get the viem contract instance
    const assetsRegistry = await hre.viem.getContractAt(
      'AssetsRegistry',
      await assetsRegistryEthers.getAddress() as Address
    );

    // Deploy AgreementsStore
    const AgreementsStore = await ethers.getContractFactory('AgreementsStore');
    const agreementsStoreEthers = await upgrades.deployProxy(
      AgreementsStore,
      [await nvmConfigEthers.getAddress()],
      { initializer: 'initialize' }
    );
    await agreementsStoreEthers.waitForDeployment();
    
    // Get the viem contract instance
    const agreementsStore = await hre.viem.getContractAt(
      'AgreementsStore',
      await agreementsStoreEthers.getAddress() as Address
    );

    // Deploy PaymentsVault
    const PaymentsVault = await ethers.getContractFactory('PaymentsVault');
    const paymentsVaultEthers = await upgrades.deployProxy(
      PaymentsVault,
      [await nvmConfigEthers.getAddress()],
      { initializer: 'initialize' }
    );
    await paymentsVaultEthers.waitForDeployment();
    
    // Get the viem contract instance
    const paymentsVault = await hre.viem.getContractAt(
      'PaymentsVault',
      await paymentsVaultEthers.getAddress() as Address
    );

    // Deploy NFT1155Credits
    const NFT1155Credits = await ethers.getContractFactory('NFT1155Credits');
    const nft1155CreditsEthers = await upgrades.deployProxy(
      NFT1155Credits,
      [await nvmConfigEthers.getAddress(), 'Nevermined Credits', 'NVMC'],
      { initializer: 'initialize' }
    );
    await nft1155CreditsEthers.waitForDeployment();
    
    // Get the viem contract instance
    const nft1155Credits = await hre.viem.getContractAt(
      'NFT1155Credits',
      await nft1155CreditsEthers.getAddress() as Address
    );

    // Get the public client for viem interactions
    const publicClient = await hre.viem.getPublicClient();

    return {
      owner,
      governor,
      user1,
      user2,
      nvmConfig,
      assetsRegistry,
      agreementsStore,
      paymentsVault,
      nft1155Credits,
      // Keep ethers instances for upgrades
      nvmConfigEthers,
      assetsRegistryEthers,
      agreementsStoreEthers,
      paymentsVaultEthers,
      nft1155CreditsEthers,
      // Keep ethers signers
      ownerSigner,
      governorSigner,
      publicClient
    };
  }

  describe('NVMConfig Upgradeability', function () {
    it('should upgrade NVMConfig to V2 and access new functionality', async function () {
      const { nvmConfig, governor, nvmConfigEthers, governorSigner } = await loadFixture(deployContracts);
      
      // Deploy the V2 implementation using ethers for the upgrades plugin
      const NVMConfigV2 = await ethers.getContractFactory('NVMConfigV2');
      const nvmConfigV2Ethers = await upgrades.upgradeProxy(await nvmConfigEthers.getAddress(), NVMConfigV2);
      
      // Get the viem contract instance for the upgraded contract
      const nvmConfigV2 = await hre.viem.getContractAt(
        'NVMConfigV2',
        await nvmConfigV2Ethers.getAddress() as Address
      );
      
      // Initialize the new version using viem
      await nvmConfigV2.write.initializeV2(['2.0.0'], {
        account: governor.account.address
      });
      
      // Check that the new functionality is accessible using viem
      const version = await nvmConfigV2.read.getVersion();
      expect(version).to.equal('2.0.0');
      
      // Check that the original functionality still works using viem
      const isGovernor = await nvmConfigV2.read.isGovernor([governor.account.address]);
      expect(isGovernor).to.be.true;
    });
  });

  describe('AssetsRegistry Upgradeability', function () {
    it('should upgrade AssetsRegistry to V2 and access new functionality', async function () {
      const { assetsRegistry, governor, assetsRegistryEthers } = await loadFixture(deployContracts);
      
      // Deploy the V2 implementation using ethers for the upgrades plugin
      const AssetsRegistryV2 = await ethers.getContractFactory('AssetsRegistryV2');
      const assetsRegistryV2Ethers = await upgrades.upgradeProxy(await assetsRegistryEthers.getAddress(), AssetsRegistryV2);
      
      // Get the viem contract instance for the upgraded contract
      const assetsRegistryV2 = await hre.viem.getContractAt(
        'AssetsRegistryV2',
        await assetsRegistryV2Ethers.getAddress() as Address
      );
      
      // Initialize the new version using viem
      await assetsRegistryV2.write.initializeV2(['2.0.0'], {
        account: governor.account.address
      });
      
      // Check that the new functionality is accessible using viem
      const assetsRegistryVersion = await assetsRegistryV2.read.getVersion();
      expect(assetsRegistryVersion).to.equal('2.0.0');
    });
  });

  describe('AgreementsStore Upgradeability', function () {
    it('should upgrade AgreementsStore to V2 and access new functionality', async function () {
      const { agreementsStore, governor, agreementsStoreEthers } = await loadFixture(deployContracts);
      
      // Deploy the V2 implementation using ethers for the upgrades plugin
      const AgreementsStoreV2 = await ethers.getContractFactory('AgreementsStoreV2');
      const agreementsStoreV2Ethers = await upgrades.upgradeProxy(await agreementsStoreEthers.getAddress(), AgreementsStoreV2);
      
      // Get the viem contract instance for the upgraded contract
      const agreementsStoreV2 = await hre.viem.getContractAt(
        'AgreementsStoreV2',
        await agreementsStoreV2Ethers.getAddress() as Address
      );
      
      // Initialize the new version using viem
      await agreementsStoreV2.write.initializeV2(['2.0.0'], {
        account: governor.account.address
      });
      
      // Check that the new functionality is accessible using viem
      const agreementsStoreVersion = await agreementsStoreV2.read.getVersion();
      expect(agreementsStoreVersion).to.equal('2.0.0');
    });
  });

  describe('PaymentsVault Upgradeability', function () {
    it('should upgrade PaymentsVault to V2 and access new functionality', async function () {
      const { paymentsVault, governor, paymentsVaultEthers } = await loadFixture(deployContracts);
      
      // Deploy the V2 implementation using ethers for the upgrades plugin
      const PaymentsVaultV2 = await ethers.getContractFactory('PaymentsVaultV2');
      const paymentsVaultV2Ethers = await upgrades.upgradeProxy(await paymentsVaultEthers.getAddress(), PaymentsVaultV2);
      
      // Get the viem contract instance for the upgraded contract
      const paymentsVaultV2 = await hre.viem.getContractAt(
        'PaymentsVaultV2',
        await paymentsVaultV2Ethers.getAddress() as Address
      );
      
      // Initialize the new version using viem
      await paymentsVaultV2.write.initializeV2(['2.0.0'], {
        account: governor.account.address
      });
      
      // Check that the new functionality is accessible using viem
      const paymentsVaultVersion = await paymentsVaultV2.read.getVersion();
      expect(paymentsVaultVersion).to.equal('2.0.0');
    });
  });

  describe('NFT1155Credits Upgradeability', function () {
    it('should upgrade NFT1155Credits to V2 and access new functionality', async function () {
      const { nft1155Credits, governor, nft1155CreditsEthers } = await loadFixture(deployContracts);
      
      // Deploy the V2 implementation using ethers for the upgrades plugin
      const NFT1155CreditsV2 = await ethers.getContractFactory('NFT1155CreditsV2');
      const nft1155CreditsV2Ethers = await upgrades.upgradeProxy(await nft1155CreditsEthers.getAddress(), NFT1155CreditsV2);
      
      // Get the viem contract instance for the upgraded contract
      const nft1155CreditsV2 = await hre.viem.getContractAt(
        'NFT1155CreditsV2',
        await nft1155CreditsV2Ethers.getAddress() as Address
      );
      
      // Initialize the new version using viem
      await nft1155CreditsV2.write.initializeV2(['2.0.0'], {
        account: governor.account.address
      });
      
      // Check that the new functionality is accessible using viem
      const nft1155CreditsVersion = await nft1155CreditsV2.read.getVersion();
      expect(nft1155CreditsVersion).to.equal('2.0.0');
    });
  });
});
