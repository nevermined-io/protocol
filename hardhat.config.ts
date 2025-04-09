import type { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox-viem'
import '@nomiclabs/hardhat-solhint'
import '@openzeppelin/hardhat-upgrades'
import '@nomicfoundation/hardhat-ignition'
import '@nomicfoundation/hardhat-foundry'
import 'hardhat-dependency-compiler'

const MNEMONIC =
  process.env.MNEMONIC || 'test test test test test test test test test test test junk'
const accounts = {
  mnemonic: MNEMONIC,
}

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.28',
    settings: {
      evmVersion: 'cancun',
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      accounts,
    },
  },
  dependencyCompiler: {
    paths: [
      '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol',
      '@openzeppelin/contracts/access/manager/AccessManager.sol',
    ],
  },
}

export default config
