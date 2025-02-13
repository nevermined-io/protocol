// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const NVMConfigModule = buildModule("NVMConfigModule", (m) => {
	
	const owner = m.getAccount(0)
	const governor = m.getAccount(0)

	const nvmConfig = m.contract("NVMConfig", [], {});
	m.call(nvmConfig, 'initialize', [owner, governor]);

	return { nvmConfig };
});

export default NVMConfigModule;
