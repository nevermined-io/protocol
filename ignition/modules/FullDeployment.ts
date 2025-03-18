// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"
import hre from 'hardhat'
import { sha3 } from "../../test/common/utils"
import { zeroAddress } from "viem"

const OWNER_ACCOUNT_INDEX = (process.env.OWNER_ACCOUNT_INDEX || 0) as number
const GOVERNOR_ACCOUNT_INDEX = (process.env.GOVERNOR_ACCOUNT_INDEX || 1) as number
const NVM_FEE_AMOUNT = (process.env.NVM_FEE_AMOUNT || 10000) as number // 1% by default
const NVM_FEE_RECEIVER = process.env.NVM_FEE_RECEIVER


const HASH_ASSETS_REGISTRY = sha3('AssetsRegistry')
const HASH_AGREEMENTS_STORE = sha3('AgreementsStore')
const HASH_PAYMENTS_VAULT = sha3('PaymentsVault')
const HASH_NFT1155CREDITS = sha3('NFT1155Credits')
const HASH_LOCKPAYMENT_CONDITION = sha3('LockPaymentCondition')
const HASH_TRANSFERCREDITS_CONDITION = sha3('TransferCreditsCondition')
const HASH_DISTRIBUTEPAYMENTS_CONDITION = sha3('DistributePaymentsCondition')
const HASH_FIXED_PAYMENT_TEMPLATE = sha3('FixedPaymentTemplate')



const NVMConfigModule = buildModule("NVMConfigModule", (m) => {
	const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
	const governor = m.getAccount(GOVERNOR_ACCOUNT_INDEX)

	const nvmConfig = m.contract("NVMConfig", [], { from: owner })
	m.call(nvmConfig, 'initialize', [owner, governor])

	m.call(nvmConfig, 'setNetworkFees', [NVM_FEE_AMOUNT, NVM_FEE_RECEIVER || owner], { from: governor })

	return { nvmConfig }
})

const LibrariesDeploymentModule = buildModule("LibrariesDeploymentModule", (m) => {
	const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
	const tokenUtils = m.library("TokenUtils", { from: owner })	

	return { tokenUtils }
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

const NFT1155CreditsModule = buildModule("NFT1155CreditsModule", (m) => {
	const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
	const nftCredits = m.contract("NFT1155Credits", [], { from: owner })	
	return { nftCredits }
})

const LockPaymentConditionModule = buildModule("LockPaymentConditionModule", (m) => {
	const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
	const lockPaymentCondition = m.contract("LockPaymentCondition", [], { 
		from: owner, 
		libraries: { TokenUtils: m.useModule(LibrariesDeploymentModule).tokenUtils } 
	})	
	return { lockPaymentCondition }
})

const TransferCreditsConditionModule = buildModule("TransferCreditsConditionModule", (m) => {
	const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
	const transferCreditsCondition = m.contract("TransferCreditsCondition", [], { from: owner })	
	return { transferCreditsCondition }
})

const DistributePaymentsConditionModule = buildModule("DistributePaymentsConditionModule", (m) => {
	const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
	const distributePaymentsCondition = m.contract("DistributePaymentsCondition", [], { 
		from: owner,
		libraries: { TokenUtils: m.useModule(LibrariesDeploymentModule).tokenUtils } 
	})	
	return { distributePaymentsCondition }
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
	const { tokenUtils } = m.useModule(LibrariesDeploymentModule)
	const { assetsRegistry } = m.useModule(AssetsRegistryModule)
	const { agreementsStore } = m.useModule(AgreementsStoreModule)
	const { paymentsVault } = m.useModule(PaymentsVaultModule)
	const { nftCredits } = m.useModule(NFT1155CreditsModule)
	const { lockPaymentCondition } = m.useModule(LockPaymentConditionModule)
	const { transferCreditsCondition } = m.useModule(TransferCreditsConditionModule)
	const { distributePaymentsCondition } = m.useModule(DistributePaymentsConditionModule)
	const { fixedPaymentTemplate } = m.useModule(TemplatesDeploymentModule)	
	
	/////////////////// CORE CONTRACTS //////////////////////////////////
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
	m.call(paymentsVault, 'initialize', [nvmConfig], { from: owner })	
	m.call(nvmConfig, 'registerContract(bytes32,address,uint256)', 
		[HASH_PAYMENTS_VAULT, paymentsVault, 1], 
		{ from: governor, id: 'PaymentsVault_registerContract' })

	/////////////////// NFT CONTRACTS //////////////////////////////////

	// NFT1155Credits
	m.call(nftCredits, 'initialize', [nvmConfig], { from: owner })	
	m.call(nvmConfig, 'registerContract(bytes32,address,uint256)', 
		[HASH_NFT1155CREDITS, nftCredits, 1], 
		{ from: governor, id: 'NFT1155Credits_registerContract' })


	/////////////////// CONDITIONS //////////////////////////////////
	// LockPaymentCondition
	m.call(lockPaymentCondition, 'initialize', [nvmConfig, assetsRegistry, agreementsStore, paymentsVault])	
	m.call(nvmConfig, 'registerContract(bytes32,address,uint256)', 
		[HASH_LOCKPAYMENT_CONDITION, lockPaymentCondition, 1], 
		{ from: governor, id: 'LockPaymentCondition_registerContract' })
	m.call(nvmConfig, 'grantCondition', [lockPaymentCondition], { from: governor , id: 'grantCondition_lockPayment' })

	// TransferCreditsCondition
	m.call(transferCreditsCondition, 'initialize', [nvmConfig, assetsRegistry, agreementsStore])	
	m.call(nvmConfig, 'registerContract(bytes32,address,uint256)', 
		[HASH_TRANSFERCREDITS_CONDITION, transferCreditsCondition, 1], 
		{ from: governor, id: 'TransferCreditsCondition_registerContract' })
	m.call(nvmConfig, 'grantCondition', [transferCreditsCondition], { from: governor , id: 'grantCondition_transferCredits' })

	// DistributePaymentsCondition
	m.call(distributePaymentsCondition, 'initialize', [nvmConfig, assetsRegistry, agreementsStore, paymentsVault])	
	m.call(nvmConfig, 'registerContract(bytes32,address,uint256)', 
		[HASH_DISTRIBUTEPAYMENTS_CONDITION, distributePaymentsCondition, 1], 
		{ from: governor, id: 'DistributePaymentsCondition_registerContract' })
	m.call(nvmConfig, 'grantCondition', [distributePaymentsCondition], { from: governor , id: 'grantCondition_distributePayments' })


	/////////////////// TEMPLATES //////////////////////////////////
	// Fixed Payment Template
	m.call(fixedPaymentTemplate, 'initialize', [fixedPaymentTemplate, agreementsStore, lockPaymentCondition, transferCreditsCondition, distributePaymentsCondition])
	m.call(nvmConfig, 'registerContract(bytes32,address,uint256)', 
	 	[HASH_FIXED_PAYMENT_TEMPLATE, fixedPaymentTemplate, 1], 
	 	{ from: governor, id: 'FixedPaymentTemplate_registerContract' })
	m.call(nvmConfig, 'grantTemplate', [fixedPaymentTemplate], { from: governor })


	/////////////////// PERMISSIONS //////////////////////////////////
	// Grant Deposit and Withdrawal permissions to Payments Vault
	const DEPOSITOR_ROLE = m.staticCall(paymentsVault, 'DEPOSITOR_ROLE', [])
	const WITHDRAW_ROLE = m.staticCall(paymentsVault, 'WITHDRAW_ROLE', [])	
	m.call(nvmConfig, 'grantRole', [DEPOSITOR_ROLE, lockPaymentCondition], { from: owner, id: 'grantRole_depositor_lockPayment' })
	m.call(nvmConfig, 'grantRole', [WITHDRAW_ROLE, distributePaymentsCondition], { from: owner, id: 'grantRole_withdraw_distributePayments' })
	
	// Grant Mint permissions to transferNFTCondition on NFT1155Credits contracts
	const CREDITS_MINTER_ROLE = m.staticCall(nftCredits, 'CREDITS_MINTER_ROLE', [])
	m.call(nvmConfig, 'grantRole', [CREDITS_MINTER_ROLE, transferCreditsCondition], { from: owner, id: 'grantRole_minter_transferCredits' })

	return { 
		nvmConfig, 		
		assetsRegistry, 
		agreementsStore,
		paymentsVault,
		nftCredits,
		lockPaymentCondition, 
		transferCreditsCondition, 
		distributePaymentsCondition,
		fixedPaymentTemplate 
	}
})

const FullDeploymentModule = buildModule("FullDeploymentModule", (m) => {
	return m.useModule(DeploymentOfContractsModule)

	// console.log(nvmConfig)
	// return { nvmConfig, paymentsVault, assetsRegistry, agreementsStore, fixedPaymentTemplate }
})

// const registerContract = (_name: string, _address: string, _version = 0) => {
// 	matchMedia.call(nvmConfig, 'registerContract', [sha3(_name), assetsRegistry])
// }

export { NVMConfigModule, FullDeploymentModule }
