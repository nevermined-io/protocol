// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import hre from 'hardhat'
import { sha3 } from '../../test/common/utils'
import { zeroAddress } from 'viem'
import { ProxyAdminModule } from './ProxyDeployment'

const OWNER_ACCOUNT_INDEX: number = Number(process.env.OWNER_ACCOUNT_INDEX || 0)
const GOVERNOR_ACCOUNT_INDEX: number = Number(process.env.GOVERNOR_ACCOUNT_INDEX ||
  1)
const NVM_FEE_AMOUNT: number = Number(process.env.NVM_FEE_AMOUNT || 10000) // 1% by default
const NVM_FEE_RECEIVER = process.env.NVM_FEE_RECEIVER

const NVMConfigModule = buildModule('NVMConfigModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
  const governor = m.getAccount(GOVERNOR_ACCOUNT_INDEX)
  
  // Deploy the implementation contract
  const nvmConfigImpl = m.contract('NVMConfig', [], { from: owner })
  
  // Get the ProxyAdmin
  const { proxyAdmin } = m.useModule(ProxyAdminModule)
  
  // Deploy the proxy with the implementation
  // Use empty bytes for initialization data - we'll initialize separately
  const emptyData = '0x'
  const nvmConfigProxy = m.contract(
    'TransparentUpgradeableProxy',
    [
      nvmConfigImpl,
      proxyAdmin,
      emptyData
    ],
    { from: owner }
  )
  
  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const nvmConfig = m.contractAt('NVMConfig', nvmConfigProxy, { id: 'NVMConfigProxyInstance' })
  
  // Initialize the contract through the proxy
  m.call(nvmConfig, 'initialize', [owner, governor])
  
  // Set network fees
  m.call(nvmConfig, 'setNetworkFees', [NVM_FEE_AMOUNT, NVM_FEE_RECEIVER || owner], { from: governor })
  
  return { nvmConfig, nvmConfigImpl, nvmConfigProxy }
})

const LibrariesDeploymentModule = buildModule(
  'LibrariesDeploymentModule',
  (m) => {
    const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
    const tokenUtils = m.library('TokenUtils', { from: owner })

    return { tokenUtils }
  }
)

const AssetsRegistryModule = buildModule('AssetsRegistryModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)

  // Deploy the implementation contract
  const assetsRegistryImpl = m.contract('AssetsRegistry', [], { from: owner })

  // Get the ProxyAdmin
  const { proxyAdmin } = m.useModule(ProxyAdminModule)

  // Get the NVMConfig
  const { nvmConfig } = m.useModule(NVMConfigModule)

  // Deploy the proxy with the implementation
  // Use empty bytes for initialization data - we'll initialize separately
  const emptyData = '0x'
  const assetsRegistryProxy = m.contract(
    'TransparentUpgradeableProxy',
    [assetsRegistryImpl, proxyAdmin, emptyData],
    { from: owner },
  )

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const assetsRegistry = m.contractAt('AssetsRegistry', assetsRegistryProxy, {
    id: 'AssetsRegistryProxyInstance',
  })

  // Initialize the contract through the proxy
  m.call(assetsRegistry, 'initialize', [nvmConfig])

  return { assetsRegistry, assetsRegistryImpl, assetsRegistryProxy }
})

const AgreementsStoreModule = buildModule('AgreementsStoreModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)

  // Deploy the implementation contract
  const agreementsStoreImpl = m.contract('AgreementsStore', [], { from: owner })

  // Get the ProxyAdmin
  const { proxyAdmin } = m.useModule(ProxyAdminModule)

  // Get the NVMConfig
  const { nvmConfig } = m.useModule(NVMConfigModule)

  // Deploy the proxy with the implementation
  // Use empty bytes for initialization data - we'll initialize separately
  const emptyData = '0x'
  const agreementsStoreProxy = m.contract(
    'TransparentUpgradeableProxy',
    [agreementsStoreImpl, proxyAdmin, emptyData],
    { from: owner },
  )

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const agreementsStore = m.contractAt('AgreementsStore', agreementsStoreProxy, {
    id: 'AgreementsStoreProxyInstance',
  })

  // Initialize the contract through the proxy
  m.call(agreementsStore, 'initialize', [nvmConfig])

  return { agreementsStore, agreementsStoreImpl, agreementsStoreProxy }
})

const PaymentsVaultModule = buildModule('PaymentsVaultModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)

  // Deploy the implementation contract
  const paymentsVaultImpl = m.contract('PaymentsVault', [], { from: owner })

  // Get the ProxyAdmin
  const { proxyAdmin } = m.useModule(ProxyAdminModule)

  // Get the NVMConfig
  const { nvmConfig } = m.useModule(NVMConfigModule)

  // Deploy the proxy with the implementation
  // Use empty bytes for initialization data - we'll initialize separately
  const emptyData = '0x'
  const paymentsVaultProxy = m.contract(
    'TransparentUpgradeableProxy',
    [paymentsVaultImpl, proxyAdmin, emptyData],
    { from: owner },
  )

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const paymentsVault = m.contractAt('PaymentsVault', paymentsVaultProxy, {
    id: 'PaymentsVaultProxyInstance',
  })

  // Initialize the contract through the proxy
  m.call(paymentsVault, 'initialize', [nvmConfig])

  return { paymentsVault, paymentsVaultImpl, paymentsVaultProxy }
})

const NFT1155CreditsModule = buildModule('NFT1155CreditsModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)

  // Deploy the implementation contract
  const nftCreditsImpl = m.contract('NFT1155Credits', [], { from: owner })

  // Get the ProxyAdmin
  const { proxyAdmin } = m.useModule(ProxyAdminModule)

  // Get the NVMConfig
  const { nvmConfig } = m.useModule(NVMConfigModule)

  // Get the AssetsRegistry
  const { assetsRegistry } = m.useModule(AssetsRegistryModule)

  // Deploy the proxy with the implementation
  // Use empty bytes for initialization data - we'll initialize separately
  const emptyData = '0x'
  const nftCreditsProxy = m.contract(
    'TransparentUpgradeableProxy',
    [nftCreditsImpl, proxyAdmin, emptyData],
    { from: owner },
  )

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const nftCredits = m.contractAt('NFT1155Credits', nftCreditsProxy, {
    id: 'NFT1155CreditsProxyInstance',
  })

  // Initialize the contract through the proxy
  m.call(nftCredits, 'initialize', [nvmConfig, assetsRegistry, 'Nevermined Credits', 'NVMC'])

  return { nftCredits, nftCreditsImpl, nftCreditsProxy }
})

const NFT1155ExpirableCreditsModule = buildModule('NFT1155ExpirableCreditsModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
  
  // Deploy the implementation contract
  const nftExpirableCreditsImpl = m.contract('NFT1155ExpirableCredits', [], { from: owner })
  
  // Get the ProxyAdmin
  const { proxyAdmin } = m.useModule(ProxyAdminModule)
  
  // Get the NVMConfig
  const { nvmConfig } = m.useModule(NVMConfigModule)
  
  // Get the AssetsRegistry
  const { assetsRegistry } = m.useModule(AssetsRegistryModule)

  // Deploy the proxy with the implementation
  // Use empty bytes for initialization data - we'll initialize separately
  const emptyData = '0x'
  const nftExpirableCreditsProxy = m.contract(
    'TransparentUpgradeableProxy',
    [
      nftExpirableCreditsImpl,
      proxyAdmin,
      emptyData
    ],
    { from: owner }
  )
  
  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const nftExpirableCredits = m.contractAt('NFT1155ExpirableCredits', nftExpirableCreditsProxy, { id: 'NFT1155ExpirableCreditsProxyInstance' })
  
  // Initialize the contract through the proxy
  m.call(nftExpirableCredits, 'initialize', [nvmConfig, assetsRegistry, 'Nevermined Expirable Credits', 'NVMEC'])
  
  return { nftExpirableCredits, nftExpirableCreditsImpl, nftExpirableCreditsProxy }
})

const LockPaymentConditionModule = buildModule(
  'LockPaymentConditionModule',
  (m) => {
    const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
    const { tokenUtils } = m.useModule(LibrariesDeploymentModule)
    const { nvmConfig } = m.useModule(NVMConfigModule)
    const { paymentsVault } = m.useModule(PaymentsVaultModule)
    const { assetsRegistry } = m.useModule(AssetsRegistryModule)
    const { agreementsStore } = m.useModule(AgreementsStoreModule)
    
    // Deploy the contract (non-upgradeable)
    const lockPaymentCondition = m.contract('LockPaymentCondition', [], { 
      from: owner, 
      libraries: { TokenUtils: tokenUtils } 
    })
    
    // Initialize the contract
    m.call(lockPaymentCondition, 'initialize', [nvmConfig, assetsRegistry, agreementsStore, paymentsVault])
    
    return { lockPaymentCondition }
  }
)

const TransferCreditsConditionModule = buildModule(
  'TransferCreditsConditionModule',
  (m) => {
    const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
    const { nvmConfig } = m.useModule(NVMConfigModule)
    const { assetsRegistry } = m.useModule(AssetsRegistryModule)
    const { agreementsStore } = m.useModule(AgreementsStoreModule)
    
    // Deploy the contract (non-upgradeable)
    const transferCreditsCondition = m.contract('TransferCreditsCondition', [], { from: owner })
    
    // Initialize the contract
    m.call(transferCreditsCondition, 'initialize', [nvmConfig, assetsRegistry, agreementsStore])
    
    return { transferCreditsCondition }
  }
)

const DistributePaymentsConditionModule = buildModule(
  'DistributePaymentsConditionModule',
  (m) => {
    const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
    const { tokenUtils } = m.useModule(LibrariesDeploymentModule)
    const { nvmConfig } = m.useModule(NVMConfigModule)
    const { paymentsVault } = m.useModule(PaymentsVaultModule)
    const { assetsRegistry } = m.useModule(AssetsRegistryModule)
    const { agreementsStore } = m.useModule(AgreementsStoreModule)
    
    // Deploy the contract (non-upgradeable)
    const distributePaymentsCondition = m.contract('DistributePaymentsCondition', [], { 
      from: owner,
      libraries: { TokenUtils: tokenUtils } 
    })
    
    // Initialize the contract
    m.call(distributePaymentsCondition, 'initialize', [nvmConfig, assetsRegistry, agreementsStore, paymentsVault])
    
    return { distributePaymentsCondition }
  }
)

const FiatSettlementConditionModule = buildModule(
  'FiatSettlementConditionModule',
  (m) => {
    const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
    const { nvmConfig } = m.useModule(NVMConfigModule)
    const { paymentsVault } = m.useModule(PaymentsVaultModule)
    const { assetsRegistry } = m.useModule(AssetsRegistryModule)
    const { agreementsStore } = m.useModule(AgreementsStoreModule)
    
    // Deploy the contract (non-upgradeable)
    const fiatSettlementCondition = m.contract('FiatSettlementCondition', [], { 
      from: owner
    })
    
    // Initialize the contract
    m.call(fiatSettlementCondition, 'initialize', [nvmConfig, assetsRegistry, agreementsStore])
    
    return { fiatSettlementCondition }
  }
)

const TemplatesDeploymentModule = buildModule(
  'TemplatesDeploymentModule',
  (m) => {
    const owner = m.getAccount(OWNER_ACCOUNT_INDEX)

    const fixedPaymentTemplate = m.contract('FixedPaymentTemplate', [], { from: owner })
    const fiatPaymentTemplate = m.contract('FiatPaymentTemplate', [], { from: owner })


    return { fixedPaymentTemplate, fiatPaymentTemplate }
  }
)

const DeploymentOfContractsModule = buildModule(
  'DeploymentOfContractsModule',
  (m) => {
    const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
    const governor = m.getAccount(GOVERNOR_ACCOUNT_INDEX)
    
    const { nvmConfig } = m.useModule(NVMConfigModule)
    const { tokenUtils } = m.useModule(LibrariesDeploymentModule)
    const { assetsRegistry } = m.useModule(AssetsRegistryModule)
    const { agreementsStore } = m.useModule(AgreementsStoreModule)
    const { paymentsVault } = m.useModule(PaymentsVaultModule)
    const { nftCredits } = m.useModule(NFT1155CreditsModule)
    const { nftExpirableCredits } = m.useModule(NFT1155ExpirableCreditsModule)
    const { lockPaymentCondition } = m.useModule(LockPaymentConditionModule)
    const { transferCreditsCondition } = m.useModule(TransferCreditsConditionModule)
    const { distributePaymentsCondition } = m.useModule(DistributePaymentsConditionModule)
    const { fiatSettlementCondition } = m.useModule(FiatSettlementConditionModule)

    const { fixedPaymentTemplate, fiatPaymentTemplate } = m.useModule(TemplatesDeploymentModule)
    
    /////////////////// CONDITIONS //////////////////////////////////
    // Grant condition permissions to all conditions
    m.call(nvmConfig, 'grantCondition', [lockPaymentCondition], { from: governor, id: 'grantCondition_lockPayment' })
    m.call(nvmConfig, 'grantCondition', [transferCreditsCondition], { from: governor, id: 'grantCondition_transferCredits' })
    m.call(nvmConfig, 'grantCondition', [distributePaymentsCondition], { from: governor, id: 'grantCondition_distributePayments' })
    m.call(nvmConfig, 'grantCondition', [fiatSettlementCondition], { from: governor, id: 'grantCondition_fiatSettlement' })

    /////////////////// TEMPLATES //////////////////////////////////
    // Fixed Payment Template
    m.call(fixedPaymentTemplate, 'initialize', [
      nvmConfig, 
      assetsRegistry,
      agreementsStore, 
      lockPaymentCondition, 
      transferCreditsCondition, 
      distributePaymentsCondition
    ])
    m.call(nvmConfig, 'grantTemplate', [fixedPaymentTemplate], { from: governor, id: 'grantTemplate_fixedPayment' })

    // Fiat Settlement Template
    m.call(fiatPaymentTemplate, 'initialize', [
      nvmConfig, 
      assetsRegistry,
      agreementsStore, 
      fiatSettlementCondition, 
      transferCreditsCondition
    ])
    m.call(nvmConfig, 'grantTemplate', [fiatPaymentTemplate], { from: governor, id: 'grantTemplate_fiatPayment' })

    /////////////////// PERMISSIONS //////////////////////////////////
    // Grant Deposit and Withdrawal permissions to Payments Vault
    const DEPOSITOR_ROLE = m.staticCall(paymentsVault, 'DEPOSITOR_ROLE', [])
    const WITHDRAW_ROLE = m.staticCall(paymentsVault, 'WITHDRAW_ROLE', [])
    m.call(nvmConfig, 'grantRole', [DEPOSITOR_ROLE, lockPaymentCondition], { from: owner, id: 'grantRole_depositor_lockPayment' })
    m.call(nvmConfig, 'grantRole', [WITHDRAW_ROLE, distributePaymentsCondition], { from: owner, id: 'grantRole_withdraw_distributePayments' })
    
    // Grant Mint permissions to transferNFTCondition on NFT1155Credits contracts
    const CREDITS_MINTER_ROLE = m.staticCall(nftCredits, 'CREDITS_MINTER_ROLE', [])
    m.call(nvmConfig, 'grantRole', [CREDITS_MINTER_ROLE, transferCreditsCondition], { from: owner, id: 'grantRole_minter_transferCredits' })
    
    // Grant Mint permissions to transferNFTCondition on NFT1155ExpirableCredits contracts
    const EXPIRABLE_CREDITS_MINTER_ROLE = m.staticCall(nftExpirableCredits, 'CREDITS_MINTER_ROLE', [])
    m.call(nvmConfig, 'grantRole', [EXPIRABLE_CREDITS_MINTER_ROLE, transferCreditsCondition], { from: owner, id: 'grantRole_minter_transferExpirableCredits' })
    
    return { 
      nvmConfig,
      assetsRegistry,
      agreementsStore,
      paymentsVault,
      nftCredits,
      nftExpirableCredits,
      lockPaymentCondition,
      transferCreditsCondition,
      distributePaymentsCondition,
      fixedPaymentTemplate,
      fiatPaymentTemplate
    }
  }
)

const FullDeploymentModule = buildModule('FullDeploymentModule', (m) => {
  const {
    nvmConfig,
    assetsRegistry,
    agreementsStore,
    paymentsVault,
    nftCredits,
    nftExpirableCredits,
    lockPaymentCondition,
    transferCreditsCondition,
    distributePaymentsCondition,
    fixedPaymentTemplate,
    fiatPaymentTemplate
  } = m.useModule(DeploymentOfContractsModule)
  return {
    nvmConfig,
    assetsRegistry,
    agreementsStore,
    paymentsVault,
    nftCredits,
    nftExpirableCredits,
    lockPaymentCondition,
    transferCreditsCondition,
    distributePaymentsCondition,
    fixedPaymentTemplate,
    fiatPaymentTemplate
  }
})

export { NVMConfigModule }
export default FullDeploymentModule
