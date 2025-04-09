// This module handles the deployment of proxy contracts for upgradeable contracts
import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { keccak256, encodePacked, fromHex } from 'viem'

const OWNER_ACCOUNT_INDEX: number = Number(process.env.OWNER_ACCOUNT_INDEX || 0)

const AccessManagerModule = buildModule('AccessManagerModule', (m) => {
  const owner = m.getAccount(OWNER_ACCOUNT_INDEX)

  // Deploy the AccessManager contract
  const accessManager = m.contract(
    '@openzeppelin/contracts/access/manager/AccessManager.sol:AccessManager',
    [owner],
    { from: owner },
  )

  return { accessManager }
})

export { AccessManagerModule }
