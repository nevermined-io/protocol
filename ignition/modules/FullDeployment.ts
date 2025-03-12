// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import hre from 'hardhat'
import { sha3 } from "../../test/common/utils"

const OWNER_ACCOUNT_INDEX = (process.env.OWNER_ACCOUNT_INDEX || 0) as number
const GOVERNOR_ACCOUNT_INDEX = (process.env.GOVERNOR_ACCOUNT_INDEX || 1) as number

const HASH_ASSETS_REGISTRY = sha3('AssetsRegistry')
const HASH_AGREEMENTS_STORE = sha3('AgreementsStore')
const HASH_PAYMENTS_VAULT = sha3('PaymentsVault')
const HASH_LOCKPAYMENT_CONDITION = sha3('LockPaymentCondition')
const HASH_FIXED_PAYMENT_TEMPLATE = sha3('FixedPaymentTemplate')


const NVMConfigModule = buildModule("NVMConfigModule", (m) => {
	const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
	const governor = m.getAccount(GOVERNOR_ACCOUNT_INDEX)

	const nvmConfig = m.contract("NVMConfig", [], { from: owner })
	m.call(nvmConfig, 'initialize', [owner, governor])

	return { nvmConfig }
})

const AssetsRegistryModule = buildModule("AssetsRegistryModule", (m) => {
	const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
	const assetsRegistry = m.contract("AssetsRegistry", [], { from: owner })	

	return { assetsRegistry }
})

const AgreementsStoreModule = buildModule("AgreementsStoreModule", (m) => {
	const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
	const agreementsStore = m.contract("AgreementsStore", [], { from: owner })	

	return { agreementsStore }
})

const PaymentsVaultModule = buildModule("PaymentsVaultModule", (m) => {
	const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
	const paymentsVault = m.contract("PaymentsVault", [], { from: owner })	
	return { paymentsVault }
})

const LockPaymentConditionModule = buildModule("LockPaymentConditionModule", (m) => {
	const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
	const lockPaymentCondition = m.contract("LockPaymentCondition", [], { from: owner })	
	return { lockPaymentCondition }
})

const TemplatesDeploymentModule = buildModule("TemplatesDeploymentModule", (m) => {
	const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
	const governor = m.getAccount(GOVERNOR_ACCOUNT_INDEX)

	const fixedPaymentTemplate = m.contract("FixedPaymentTemplate", [], { from: owner })	

	return { fixedPaymentTemplate }
})

const DeploymentOfContractsModule = buildModule("DeploymentOfContractsModule", (m) => {

	const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
	const governor = m.getAccount(GOVERNOR_ACCOUNT_INDEX)
	
	const { nvmConfig } = m.useModule(NVMConfigModule)
	const { assetsRegistry } = m.useModule(AssetsRegistryModule)
	const { agreementsStore } = m.useModule(AgreementsStoreModule)
	const { paymentsVault } = m.useModule(PaymentsVaultModule)
	const { lockPaymentCondition } = m.useModule(LockPaymentConditionModule)
	const { fixedPaymentTemplate } = m.useModule(TemplatesDeploymentModule)	
	
	// Assets Registry
	m.call(assetsRegistry, 'initialize', [nvmConfig])	
	m.call(nvmConfig, 'registerContract(bytes32,address,uint256)', 
		[HASH_ASSETS_REGISTRY, assetsRegistry, 1], 
		{ from: governor, id: 'AssetsRegistry_registerContract' })

	// AgreementsStore
	m.call(agreementsStore, 'initialize', [nvmConfig])	
	m.call(nvmConfig, 'registerContract(bytes32,address,uint256)', 
		[HASH_AGREEMENTS_STORE, agreementsStore, 1], 
		{ from: governor, id: 'AgreementsStore_registerContract' })

	// Payments Vault
	m.call(paymentsVault, 'initialize', [owner, nvmConfig])	
	m.call(nvmConfig, 'registerContract(bytes32,address,uint256)', 
		[HASH_PAYMENTS_VAULT, paymentsVault, 1], 
		{ from: governor, id: 'PaymentsVault_registerContract' })

// LockPaymentCondition
	m.call(lockPaymentCondition, 'initialize', [nvmConfig, assetsRegistry, agreementsStore, paymentsVault])	
	m.call(nvmConfig, 'registerContract(bytes32,address,uint256)', 
		[HASH_LOCKPAYMENT_CONDITION, lockPaymentCondition, 1], 
		{ from: governor, id: 'LockPaymentCondition_registerContract' })

	// Fixed Payment Template
	m.call(fixedPaymentTemplate, 'initialize', [fixedPaymentTemplate])			
	m.call(nvmConfig, 'registerContract(bytes32,address,uint256)', 
		[HASH_FIXED_PAYMENT_TEMPLATE, fixedPaymentTemplate, 1], 
		{ from: governor, id: 'FixedPaymentTemplate_registerContract' })
	m.call(nvmConfig, 'grantTemplate', [fixedPaymentTemplate], { from: governor })

	// Grant Deposit and Withdrawal permissions to Payments Vault
	const DEPOSIT_ROLE = m.staticCall(paymentsVault, 'DEPOSIT_ROLE', [])
	const WITHDRAW_ROLE = m.staticCall(paymentsVault, 'WITHDRAW_ROLE', [])
	m.call(paymentsVault, 'grantRole', [DEPOSIT_ROLE, lockPaymentCondition], { from: owner })

	return { nvmConfig, paymentsVault, assetsRegistry, lockPaymentCondition, fixedPaymentTemplate }
})

const FullDeploymentModule = buildModule("FullDeploymentModule", (m) => {
	const { nvmConfig, paymentsVault, assetsRegistry, fixedPaymentTemplate } = m.useModule(DeploymentOfContractsModule)

	console.log(nvmConfig)
	return { nvmConfig, paymentsVault, assetsRegistry, fixedPaymentTemplate }
})

// const registerContract = (_name: string, _address: string, _version = 0) => {
// 	matchMedia.call(nvmConfig, 'registerContract', [sha3(_name), assetsRegistry])
// }

export { NVMConfigModule, FullDeploymentModule }
