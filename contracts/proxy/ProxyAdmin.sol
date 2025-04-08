// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
pragma solidity ^0.8.28;

import { ITransparentUpgradeableProxy } from '@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';

/**
 * @title ProxyAdmin
 * @dev This contract is the admin of all proxies deployed through the ProxyFactory.
 */
contract ProxyAdmin is Ownable {
  /**
   * @dev Error thrown when a proxy call fails
   */
  error ProxyCallFailed();
  /**
   * @dev The version of the upgrade interface of the contract.
   */

  string public constant UPGRADE_INTERFACE_VERSION = '5.0.0';

  /**
   * @dev Constructor function
   */
  constructor(address initialOwner) Ownable(initialOwner) {}

  /**
   * @dev Returns the current implementation of a proxy.
   * @param proxy Address of the proxy to query.
   * @return The address of the current implementation of the proxy.
   */
  function getProxyImplementation(address proxy) public view returns (address) {
    // We need to manually run the static call since the getter cannot be flagged as view
    // bytes4(keccak256("implementation()")) == 0x5c60da1b
    (bool success, bytes memory returndata) = proxy.staticcall(hex'5c60da1b');
    if (!success) revert ProxyCallFailed();
    return abi.decode(returndata, (address));
  }

  /**
   * @dev Returns the admin of a proxy.
   * @param proxy Address of the proxy to query.
   * @return The address of the current admin of the proxy.
   */
  function getProxyAdmin(address proxy) public view returns (address) {
    // We need to manually run the static call since the getter cannot be flagged as view
    // bytes4(keccak256("admin()")) == 0xf851a440
    (bool success, bytes memory returndata) = proxy.staticcall(hex'f851a440');
    if (!success) revert ProxyCallFailed();
    return abi.decode(returndata, (address));
  }

  /**
   * @dev Upgrades `proxy` to `implementation` and calls a function on the new implementation.
   * See {TransparentUpgradeableProxy-upgradeToAndCall}.
   *
   * Requirements:
   *
   * - This contract must be the admin of `proxy`.
   * - If `data` is empty, `msg.value` must be zero.
   */
  function upgradeAndCall(
    ITransparentUpgradeableProxy proxy,
    address implementation,
    bytes memory data
  ) public payable virtual onlyOwner {
    proxy.upgradeToAndCall{ value: msg.value }(implementation, data);
  }
}
