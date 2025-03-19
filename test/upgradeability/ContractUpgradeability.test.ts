import { expect } from 'chai';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { ethers, upgrades } from 'hardhat';

describe('Contract Upgradeability', function () {
  // Fixture to deploy all the contracts
  async function deployContracts() {
    const [owner, governor, user1, user2] = await ethers.getSigners();

    // Deploy NVMConfig
    const NVMConfig = await ethers.getContractFactory('NVMConfig');
    const nvmConfig = await upgrades.deployProxy(
      NVMConfig,
      [owner.address, governor.address],
      { initializer: 'initialize' }
    );
    await nvmConfig.waitForDeployment();

    // Deploy AssetsRegistry
    const AssetsRegistry = await ethers.getContractFactory('AssetsRegistry');
    const assetsRegistry = await upgrades.deployProxy(
      AssetsRegistry,
      [await nvmConfig.getAddress()],
      { initializer: 'initialize' }
    );
    await assetsRegistry.waitForDeployment();

    // Deploy AgreementsStore
    const AgreementsStore = await ethers.getContractFactory('AgreementsStore');
    const agreementsStore = await upgrades.deployProxy(
      AgreementsStore,
      [await nvmConfig.getAddress()],
      { initializer: 'initialize' }
    );
    await agreementsStore.waitForDeployment();

    // Deploy PaymentsVault
    const PaymentsVault = await ethers.getContractFactory('PaymentsVault');
    const paymentsVault = await upgrades.deployProxy(
      PaymentsVault,
      [await nvmConfig.getAddress()],
      { initializer: 'initialize' }
    );
    await paymentsVault.waitForDeployment();

    // Skip NFT1155Credits for now since it's not properly upgradeable

    return {
      owner,
      governor,
      user1,
      user2,
      nvmConfig,
      assetsRegistry,
      agreementsStore,
      paymentsVault
    };
  }

  describe('NVMConfig Upgradeability', function () {
    it('should upgrade NVMConfig to V2 and access new functionality', async function () {
      const { nvmConfig, governor } = await loadFixture(deployContracts);
      
      // Deploy the V2 implementation
      const NVMConfigV2 = await ethers.getContractFactory('NVMConfigV2');
      const nvmConfigV2 = await upgrades.upgradeProxy(await nvmConfig.getAddress(), NVMConfigV2);
      
      // Initialize the new version
      await nvmConfigV2.connect(governor).initializeV2('2.0.0');
      
      // Check that the new functionality is accessible
      expect(await nvmConfigV2.getVersion()).to.equal('2.0.0');
      
      // Check that the original functionality still works
      expect(await nvmConfigV2.isGovernor(governor.address)).to.be.true;
    });
  });

  describe('AssetsRegistry Upgradeability', function () {
    it('should upgrade AssetsRegistry to V2 and access new functionality', async function () {
      const { assetsRegistry, governor } = await loadFixture(deployContracts);
      
      // Deploy the V2 implementation
      const AssetsRegistryV2 = await ethers.getContractFactory('AssetsRegistryV2');
      const assetsRegistryV2 = await upgrades.upgradeProxy(await assetsRegistry.getAddress(), AssetsRegistryV2);
      
      // Initialize the new version
      await assetsRegistryV2.connect(governor).initializeV2('2.0.0');
      
      // Check that the new functionality is accessible
      expect(await assetsRegistryV2.getVersion()).to.equal('2.0.0');
    });
  });

  describe('AgreementsStore Upgradeability', function () {
    it('should upgrade AgreementsStore to V2 and access new functionality', async function () {
      const { agreementsStore, governor } = await loadFixture(deployContracts);
      
      // Deploy the V2 implementation
      const AgreementsStoreV2 = await ethers.getContractFactory('AgreementsStoreV2');
      const agreementsStoreV2 = await upgrades.upgradeProxy(await agreementsStore.getAddress(), AgreementsStoreV2);
      
      // Initialize the new version
      await agreementsStoreV2.connect(governor).initializeV2('2.0.0');
      
      // Check that the new functionality is accessible
      expect(await agreementsStoreV2.getVersion()).to.equal('2.0.0');
    });
  });

  describe('PaymentsVault Upgradeability', function () {
    it('should upgrade PaymentsVault to V2 and access new functionality', async function () {
      const { paymentsVault, governor } = await loadFixture(deployContracts);
      
      // Deploy the V2 implementation
      const PaymentsVaultV2 = await ethers.getContractFactory('PaymentsVaultV2');
      const paymentsVaultV2 = await upgrades.upgradeProxy(await paymentsVault.getAddress(), PaymentsVaultV2);
      
      // Initialize the new version
      await paymentsVaultV2.connect(governor).initializeV2('2.0.0');
      
      // Check that the new functionality is accessible
      expect(await paymentsVaultV2.getVersion()).to.equal('2.0.0');
    });
  });
});
