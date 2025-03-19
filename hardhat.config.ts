import type { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox-viem"
import "@nomiclabs/hardhat-solhint"
import "@openzeppelin/hardhat-upgrades"

const MNEMONIC =
  process.env.MNEMONIC ||
  'taxi music thumb unique chat sand crew more leg another off lamp'
const accounts = {
  mnemonic: MNEMONIC,
}

const config: HardhatUserConfig = {
  solidity: '0.8.28',
  networks: {
    hardhat: {
      accounts,
    },
  },
}

export default config
