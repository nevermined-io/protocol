import type { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox-viem'
import '@nomiclabs/hardhat-solhint'
import '@openzeppelin/hardhat-upgrades'
import '@nomicfoundation/hardhat-ignition'
import '@nomicfoundation/hardhat-foundry'


const MNEMONIC =
  process.env.MNEMONIC ||
  'test test test test test test test test test test test junk'
const accounts = {
  mnemonic: MNEMONIC,
}

const config: HardhatUserConfig = {

  solidity: {
    version: '0.8.28',
    settings: {
      evmVersion: 'cancun',
    },
  },
  networks: {
    hardhat: {
      accounts,
    },
  },
}

export default config
