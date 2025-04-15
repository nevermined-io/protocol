// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { zeroAddress } from 'viem'
import { AccessManagerModule } from './AccessManger'

const OWNER_ACCOUNT_INDEX: number = Number(process.env.OWNER_ACCOUNT_INDEX || 0)
const GOVERNOR_ACCOUNT_INDEX: number = Number(process.env.GOVERNOR_ACCOUNT_INDEX || 1)
const NVM_FEE_AMOUNT: number = Number(process.env.NVM_FEE_AMOUNT || 10000) // 1% by default
const NVM_FEE_RECEIVER = process.env.NVM_FEE_RECEIVER

const NVMConfigModule = buildModule('NVMConfigModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
  const governor = m.getAccount(GOVERNOR_ACCOUNT_INDEX)

  // Deploy the implementation contract
  const nvmConfigImpl = m.contract('NVMConfig', [], { from: owner })

  // Get the AccessManager
  const { accessManager } = m.useModule(AccessManagerModule)

  // Deploy the proxy with the implementation
  const initData = m.encodeFunctionCall(nvmConfigImpl, 'initialize', [
    owner,
    accessManager,
    governor,
  ])
  const nvmConfigProxy = m.contract('ERC1967Proxy', [nvmConfigImpl, initData], {
    from: owner,
  })

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const nvmConfig = m.contractAt('NVMConfig', nvmConfigProxy, { id: 'NVMConfigProxyInstance' })

  // Set network fees
  m.call(nvmConfig, 'setNetworkFees', [NVM_FEE_AMOUNT, NVM_FEE_RECEIVER || owner], {
    from: governor,
  })

  return { nvmConfig, nvmConfigImpl, nvmConfigProxy }
})

const LibrariesDeploymentModule = buildModule('LibrariesDeploymentModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
  const tokenUtils = m.library('TokenUtils', { from: owner })

  return { tokenUtils }
})

const AssetsRegistryModule = buildModule('AssetsRegistryModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)

  // Deploy the implementation contract
  const assetsRegistryImpl = m.contract('AssetsRegistry', [], { from: owner })

  // Get the AccessManager
  const { accessManager } = m.useModule(AccessManagerModule)

  // Get the NVMConfig
  const { nvmConfig } = m.useModule(NVMConfigModule)

  // Deploy the proxy with the implementation
  const initData = m.encodeFunctionCall(assetsRegistryImpl, 'initialize', [
    nvmConfig,
    accessManager,
  ])
  const assetsRegistryProxy = m.contract('ERC1967Proxy', [assetsRegistryImpl, initData], {
    from: owner,
  })

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const assetsRegistry = m.contractAt('AssetsRegistry', assetsRegistryProxy, {
    id: 'AssetsRegistryProxyInstance',
  })

  return { assetsRegistry, assetsRegistryImpl, assetsRegistryProxy }
})

const AgreementsStoreModule = buildModule('AgreementsStoreModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)

  // Deploy the implementation contract
  const agreementsStoreImpl = m.contract('AgreementsStore', [], { from: owner })

  // Get the AccessManager
  const { accessManager } = m.useModule(AccessManagerModule)

  // Get the NVMConfig
  const { nvmConfig } = m.useModule(NVMConfigModule)

  // Deploy the proxy with the implementation
  const initData = m.encodeFunctionCall(agreementsStoreImpl, 'initialize', [
    nvmConfig,
    accessManager,
  ])
  const agreementsStoreProxy = m.contract('ERC1967Proxy', [agreementsStoreImpl, initData], {
    from: owner,
  })

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const agreementsStore = m.contractAt('AgreementsStore', agreementsStoreProxy, {
    id: 'AgreementsStoreProxyInstance',
  })

  return { agreementsStore, agreementsStoreImpl, agreementsStoreProxy }
})

const PaymentsVaultModule = buildModule('PaymentsVaultModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)

  // Deploy the implementation contract
  const paymentsVaultImpl = m.contract('PaymentsVault', [], { from: owner })

  // Get the AccessManager
  const { accessManager } = m.useModule(AccessManagerModule)

  // Get the NVMConfig
  const { nvmConfig } = m.useModule(NVMConfigModule)

  // Deploy the proxy with the implementation
  const initData = m.encodeFunctionCall(paymentsVaultImpl, 'initialize', [nvmConfig, accessManager])
  const paymentsVaultProxy = m.contract('ERC1967Proxy', [paymentsVaultImpl, initData], {
    from: owner,
  })

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const paymentsVault = m.contractAt('PaymentsVault', paymentsVaultProxy, {
    id: 'PaymentsVaultProxyInstance',
  })

  return { paymentsVault, paymentsVaultImpl, paymentsVaultProxy }
})

const NFT1155CreditsModule = buildModule('NFT1155CreditsModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)

  // Deploy the implementation contract
  const nftCreditsImpl = m.contract('NFT1155Credits', [], { from: owner })

  // Get the ProxyAdmin
  const { accessManager } = m.useModule(AccessManagerModule)

  // Get the NVMConfig
  const { nvmConfig } = m.useModule(NVMConfigModule)

  // Get the AssetsRegistry
  const { assetsRegistry } = m.useModule(AssetsRegistryModule)

  // Deploy the proxy with the implementation
  const initData = m.encodeFunctionCall(nftCreditsImpl, 'initialize', [
    nvmConfig,
    accessManager,
    assetsRegistry,
    'Nevermined Credits',
    'NVMC',
  ])
  const nftCreditsProxy = m.contract('ERC1967Proxy', [nftCreditsImpl, initData], {
    from: owner,
  })

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const nftCredits = m.contractAt('NFT1155Credits', nftCreditsProxy, {
    id: 'NFT1155CreditsProxyInstance',
  })

  return { nftCredits, nftCreditsImpl, nftCreditsProxy }
})

const NFT1155ExpirableCreditsModule = buildModule('NFT1155ExpirableCreditsModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)

  // Deploy the implementation contract
  const nftExpirableCreditsImpl = m.contract('NFT1155ExpirableCredits', [], { from: owner })

  // Get the AccessManager
  const { accessManager } = m.useModule(AccessManagerModule)

  // Get the NVMConfig
  const { nvmConfig } = m.useModule(NVMConfigModule)

  // Get the AssetsRegistry
  const { assetsRegistry } = m.useModule(AssetsRegistryModule)

  // Deploy the proxy with the implementation
  const initData = m.encodeFunctionCall(nftExpirableCreditsImpl, 'initialize', [
    nvmConfig,
    accessManager,
    assetsRegistry,
    'Nevermined Expirable Credits',
    'NVMEC',
  ])
  const nftExpirableCreditsProxy = m.contract('ERC1967Proxy', [nftExpirableCreditsImpl, initData], {
    from: owner,
  })

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const nftExpirableCredits = m.contractAt('NFT1155ExpirableCredits', nftExpirableCreditsProxy, {
    id: 'NFT1155ExpirableCreditsProxyInstance',
  })

  return { nftExpirableCredits, nftExpirableCreditsImpl, nftExpirableCreditsProxy }
})

const LockPaymentConditionModule = buildModule('LockPaymentConditionModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
  const { tokenUtils } = m.useModule(LibrariesDeploymentModule)
  const { nvmConfig } = m.useModule(NVMConfigModule)
  const { paymentsVault } = m.useModule(PaymentsVaultModule)
  const { assetsRegistry } = m.useModule(AssetsRegistryModule)
  const { agreementsStore } = m.useModule(AgreementsStoreModule)

  // Deploy the implementation contract
  const lockPaymentConditionImpl = m.contract('LockPaymentCondition', [], {
    from: owner,
    libraries: { TokenUtils: tokenUtils },
  })

  // Deploy the proxy with the implementation. Set authority to zeroAddress to renounce upgradeability.
  const initData = m.encodeFunctionCall(lockPaymentConditionImpl, 'initialize', [
    nvmConfig,
    zeroAddress,
    assetsRegistry,
    agreementsStore,
    paymentsVault,
  ])
  const lockPaymentConditionProxy = m.contract(
    'ERC1967Proxy',
    [lockPaymentConditionImpl, initData],
    {
      from: owner,
    },
  )

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const lockPaymentCondition = m.contractAt('LockPaymentCondition', lockPaymentConditionProxy, {
    id: 'LockPaymentConditionProxyInstance',
  })

  return { lockPaymentCondition }
})

const TransferCreditsConditionModule = buildModule('TransferCreditsConditionModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
  const { nvmConfig } = m.useModule(NVMConfigModule)
  const { assetsRegistry } = m.useModule(AssetsRegistryModule)
  const { agreementsStore } = m.useModule(AgreementsStoreModule)

  // Deploy the implementation contract
  const transferCreditsConditionImpl = m.contract('TransferCreditsCondition', [], {
    from: owner,
  })

  // Deploy the proxy with the implementation. Set authority to zeroAddress to renounce upgradeability.
  const initData = m.encodeFunctionCall(transferCreditsConditionImpl, 'initialize', [
    nvmConfig,
    zeroAddress,
    assetsRegistry,
    agreementsStore,
  ])
  const transferCreditsConditionProxy = m.contract(
    'ERC1967Proxy',
    [transferCreditsConditionImpl, initData],
    {
      from: owner,
    },
  )

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const transferCreditsCondition = m.contractAt(
    'TransferCreditsCondition',
    transferCreditsConditionProxy,
    {
      id: 'TransferCreditsConditionProxyInstance',
    },
  )

  return { transferCreditsCondition }
})

const DistributePaymentsConditionModule = buildModule('DistributePaymentsConditionModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
  const { tokenUtils } = m.useModule(LibrariesDeploymentModule)
  const { nvmConfig } = m.useModule(NVMConfigModule)
  const { paymentsVault } = m.useModule(PaymentsVaultModule)
  const { assetsRegistry } = m.useModule(AssetsRegistryModule)
  const { agreementsStore } = m.useModule(AgreementsStoreModule)

  // Deploy the implementation contract
  const distributePaymentsConditionImpl = m.contract('DistributePaymentsCondition', [], {
    from: owner,
    libraries: { TokenUtils: tokenUtils },
  })

  // Deploy the proxy with the implementation. Set authority to zeroAddress to renounce upgradeability.
  const initData = m.encodeFunctionCall(distributePaymentsConditionImpl, 'initialize', [
    nvmConfig,
    zeroAddress,
    assetsRegistry,
    agreementsStore,
    paymentsVault,
  ])
  const distributePaymentsConditionProxy = m.contract(
    'ERC1967Proxy',
    [distributePaymentsConditionImpl, initData],
    {
      from: owner,
    },
  )

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const distributePaymentsCondition = m.contractAt(
    'DistributePaymentsCondition',
    distributePaymentsConditionProxy,
    {
      id: 'DistributePaymentsConditionProxyInstance',
    },
  )

  return { distributePaymentsCondition }
})

const FiatSettlementConditionModule = buildModule('FiatSettlementConditionModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
  const { nvmConfig } = m.useModule(NVMConfigModule)
  const { assetsRegistry } = m.useModule(AssetsRegistryModule)
  const { agreementsStore } = m.useModule(AgreementsStoreModule)

  // Deploy the implementation contract
  const fiatSettlementConditionImpl = m.contract('FiatSettlementCondition', [], {
    from: owner
  })

  // Deploy the proxy with the implementation. Set authority to zeroAddress to renounce upgradeability.
  const initData = m.encodeFunctionCall(fiatSettlementConditionImpl, 'initialize', [
    nvmConfig,
    zeroAddress,
    assetsRegistry,
    agreementsStore,
  ])
  const fiatSettlementConditionProxy = m.contract(
    'ERC1967Proxy',
    [fiatSettlementConditionImpl, initData],
    {
      from: owner,
    },
  )

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const fiatSettlementCondition = m.contractAt('FiatSettlementCondition', fiatSettlementConditionProxy, {
    id: 'FiatSettlementConditionProxyInstance',
  })

  return { fiatSettlementCondition }
})

const TemplatesDeploymentModule = buildModule('TemplatesDeploymentModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)

  // Deploy the implementation contract
  const fixedPaymentTemplateImpl = m.contract('FixedPaymentTemplate', [], { from: owner })

  const fixedPaymentTemplateProxy = m.contract('ERC1967Proxy', [fixedPaymentTemplateImpl, '0x'], {
    from: owner, id: 'ERC1967Proxy_FixedPaymentTemplateProxy'
  })

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const fixedPaymentTemplate = m.contractAt('FixedPaymentTemplate', fixedPaymentTemplateProxy, {
    id: 'FixedPaymentTemplateProxyInstance',
  })

  // FIAT Template
  const fiatPaymentTemplateImpl = m.contract('FiatPaymentTemplate', [], { from: owner })

  const fiatPaymentTemplateProxy = m.contract('ERC1967Proxy', [fiatPaymentTemplateImpl, '0x'], {
    from: owner,  id: 'ERC1967Proxy_FiatPaymentTemplateProxy'
  })

  // Create a contract instance that points to the proxy but uses the ABI of the implementation
  const fiatPaymentTemplate = m.contractAt('FiatPaymentTemplate', fiatPaymentTemplateProxy, {
    id: 'FiatPaymentTemplateProxyInstance',
  })

  return { fixedPaymentTemplate, fiatPaymentTemplate }
})

const DeploymentOfContractsModule = buildModule('DeploymentOfContractsModule', (m) => {
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
  m.call(nvmConfig, 'grantCondition', [lockPaymentCondition], {
    from: governor,
    id: 'grantCondition_lockPayment',
  })
  m.call(nvmConfig, 'grantCondition', [transferCreditsCondition], {
    from: governor,
    id: 'grantCondition_transferCredits',
  })
  m.call(nvmConfig, 'grantCondition', [distributePaymentsCondition], {
    from: governor,
    id: 'grantCondition_distributePayments',
  })
  m.call(nvmConfig, 'grantCondition', [fiatSettlementCondition], {
    from: governor,
    id: 'grantCondition_fiatSettlement',
  })

  /////////////////// TEMPLATES //////////////////////////////////
  // Fixed Payment Template
  m.call(fixedPaymentTemplate, 'initialize', [
    nvmConfig,
    zeroAddress,
    assetsRegistry,
    agreementsStore,
    lockPaymentCondition,
    transferCreditsCondition,
    distributePaymentsCondition,
  ])
  m.call(nvmConfig, 'grantTemplate', [fixedPaymentTemplate], { from: governor,  id: 'grantTemplate_fixedPayment' })
  // Fixed Payment Template
  m.call(fiatPaymentTemplate, 'initialize', [
    nvmConfig,
    zeroAddress,
    assetsRegistry,
    agreementsStore,
    fiatSettlementCondition,
    transferCreditsCondition
  ])
  m.call(nvmConfig, 'grantTemplate', [fiatPaymentTemplate], { from: governor,  id: 'grantTemplate_fiatPayment' })

  /////////////////// PERMISSIONS //////////////////////////////////
  // Grant Deposit and Withdrawal permissions to Payments Vault
  const DEPOSITOR_ROLE = m.staticCall(paymentsVault, 'DEPOSITOR_ROLE', [])
  const WITHDRAW_ROLE = m.staticCall(paymentsVault, 'WITHDRAW_ROLE', [])
  m.call(nvmConfig, 'grantRole', [DEPOSITOR_ROLE, lockPaymentCondition], {
    from: owner,
    id: 'grantRole_depositor_lockPayment',
  })
  m.call(nvmConfig, 'grantRole', [WITHDRAW_ROLE, distributePaymentsCondition], {
    from: owner,
    id: 'grantRole_withdraw_distributePayments',
  })

  // Grant Mint permissions to transferNFTCondition on NFT1155Credits contracts
  const CREDITS_MINTER_ROLE = m.staticCall(nftCredits, 'CREDITS_MINTER_ROLE', [])
  m.call(nvmConfig, 'grantRole', [CREDITS_MINTER_ROLE, transferCreditsCondition], {
    from: owner,
    id: 'grantRole_minter_transferCredits',
  })

  // Grant Mint permissions to transferNFTCondition on NFT1155ExpirableCredits contracts
  const EXPIRABLE_CREDITS_MINTER_ROLE = m.staticCall(nftExpirableCredits, 'CREDITS_MINTER_ROLE', [])
  m.call(nvmConfig, 'grantRole', [EXPIRABLE_CREDITS_MINTER_ROLE, transferCreditsCondition], {
    from: owner,
    id: 'grantRole_minter_transferExpirableCredits',
  })

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
    fiatSettlementCondition,
    fixedPaymentTemplate,
    fiatPaymentTemplate
  }
})

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
    fiatSettlementCondition,
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
    fiatSettlementCondition,
    fixedPaymentTemplate,
    fiatPaymentTemplate
  }
})

export { NVMConfigModule }
export default FullDeploymentModule
