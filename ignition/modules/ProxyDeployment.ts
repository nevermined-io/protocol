// This module handles the deployment of proxy contracts for upgradeable contracts
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { zeroAddress } from "viem";

const OWNER_ACCOUNT_INDEX = (process.env.OWNER_ACCOUNT_INDEX || 0) as number;
const GOVERNOR_ACCOUNT_INDEX = (process.env.GOVERNOR_ACCOUNT_INDEX || 1) as number;

const ProxyAdminModule = buildModule("ProxyAdminModule", (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX);
  
  // Deploy the ProxyAdmin contract that will manage all proxies
  const proxyAdmin = m.contract("ProxyAdmin", [], { from: owner });
  
  return { proxyAdmin };
});

export { ProxyAdminModule };
