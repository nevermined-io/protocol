import type { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox-viem"
import "@nomiclabs/hardhat-solhint"

const MNEMONIC = process.env.MNEMONIC || 'taxi music thumb unique chat sand crew more leg another off lamp'
const accounts = {
	mnemonic: MNEMONIC
}

const config: HardhatUserConfig = {
	solidity: {
		version: "0.8.28",
		settings: {
			optimizer: {
				enabled: true,
				runs: 200
			}
		}
	},
	networks: {
		hardhat: {
			accounts
		}
	}
}

export default config
