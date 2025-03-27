// This module handles the deployment of proxy contracts for upgradeable contracts
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules"

const OWNER_ACCOUNT_INDEX: number = Number(process.env.OWNER_ACCOUNT_INDEX || 0)

const ProxyAdminModule = buildModule("ProxyAdminModule", (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)
  
  // Deploy the ProxyAdmin contract that will manage all proxies
  const proxyAdmin = m.contract("contracts/proxy/ProxyAdmin.sol:ProxyAdmin", [owner], { from: owner })
  
  return { proxyAdmin }
})

export { ProxyAdminModule }
