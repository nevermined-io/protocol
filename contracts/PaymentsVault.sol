// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {INVMConfig} from './interfaces/INVMConfig.sol';
import {IVault} from './interfaces/IVault.sol';

import {AccessManagedUUPSUpgradeable} from './proxy/AccessManagedUUPSUpgradeable.sol';
import {ReentrancyGuardTransientUpgradeable} from
    '@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol';

import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title PaymentsVault
 * @author Nevermined AG
 * @notice This contract serves as a secure vault for holding and managing native tokens (ETH) and ERC20 tokens
 * in the Nevermined ecosystem.
 * @dev The contract implements:
 * - Role-based access control via OpenZeppelin's AccessManager integration
 * - Security against reentrancy attacks via ReentrancyGuardTransientUpgradeable
 * - Upgradeability using UUPS (Universal Upgradeable Proxy Standard) pattern
 * - ERC-7201 namespaced storage pattern to prevent storage collisions during upgrades
 *
 * The contract handles two main token types:
 * 1. Native tokens (ETH)
 * 2. ERC20 tokens
 *
 * Access is controlled via two primary roles:
 * - DEPOSITOR_ROLE: Allows depositing tokens into the vault
 * - WITHDRAW_ROLE: Allows withdrawing tokens from the vault
 */
contract PaymentsVault is IVault, ReentrancyGuardTransientUpgradeable, AccessManagedUUPSUpgradeable {
    /**
     * @notice Role allowing to deposit assets into the Vault
     */
    bytes32 public constant DEPOSITOR_ROLE = keccak256('VAULT_DEPOSITOR_ROLE');

    /**
     * @notice Role allowing to withdraw assets from the Vault
     */
    bytes32 public constant WITHDRAW_ROLE = keccak256('VAULT_WITHDRAW_ROLE');

    /**
     * @dev Storage slot for PaymentsVaultStorage using ERC-7201 namespaced storage pattern
     * @dev Calculated as: keccak256(abi.encode(uint256(keccak256("nevermined.paymentsvault.storage")) - 1)) & ~bytes32(uint256(0xff))
     * @dev This pattern ensures storage safety during upgrades by using a unique storage location
     */
    bytes32 private constant PAYMENTS_VAULT_STORAGE_LOCATION =
        0x80a73158257d9dc2a97871b2d2c51b86390aa280667a4b04612145b2777aba00;

    /**
     * @dev Contract storage structure following ERC-7201 namespaced storage pattern
     * @custom:storage-location erc7201:nevermined.paymentsvault.storage
     */
    struct PaymentsVaultStorage {
        INVMConfig nvmConfig;
    }

    /**
     * @notice Initializes the PaymentsVault contract
     * @param _nvmConfigAddress Address of the NVMConfig contract managing system configuration
     * @param _authority Address of the AccessManager contract handling permissions
     * @dev This function can only be called once due to the initializer modifier
     * @dev Sets up the access control system and initializes the reentrancy guard
     * @dev This replaces the constructor for upgradeable contracts
     */
    function initialize(INVMConfig _nvmConfigAddress, IAccessManager _authority) external initializer {
        ReentrancyGuardTransientUpgradeable.__ReentrancyGuardTransient_init();
        PaymentsVaultStorage storage $ = _getPaymentsVaultStorage();
        $.nvmConfig = _nvmConfigAddress;
        __AccessManagedUUPSUpgradeable_init(address(_authority));
    }

    // solhint-disable-next-line no-complex-fallback
    /**
     * @notice Fallback function to receive native tokens (ETH) sent directly to the contract
     * @dev Only addresses with DEPOSITOR_ROLE can send native tokens directly to the contract
     * @dev Emits ReceivedNativeToken event on successful deposit
     * @dev This function enables the contract to receive ETH transfers
     */
    receive() external payable {
        if (!_getPaymentsVaultStorage().nvmConfig.hasRole(msg.sender, DEPOSITOR_ROLE)) {
            revert InvalidRole(msg.sender, DEPOSITOR_ROLE);
        }
        emit ReceivedNativeToken(msg.sender, msg.value);
    }

    /**
     * @notice Deposits native tokens (ETH) to the vault
     * @dev Caller must have DEPOSITOR_ROLE to call this function
     * @dev Protected against reentrancy attacks with nonReentrant modifier
     * @dev Emits ReceivedNativeToken event on successful deposit
     * @dev This function provides an explicit method to deposit ETH as an alternative to using the receive() function
     */
    function depositNativeToken() external payable nonReentrant {
        if (!_getPaymentsVaultStorage().nvmConfig.hasRole(msg.sender, DEPOSITOR_ROLE)) {
            revert InvalidRole(msg.sender, DEPOSITOR_ROLE);
        }
        emit ReceivedNativeToken(msg.sender, msg.value);
    }

    /**
     * @notice Withdraws native tokens (ETH) from the vault to a specified receiver
     * @param _amount Amount of native tokens to withdraw
     * @param _receiver Address to receive the withdrawn tokens
     * @dev Caller must have WITHDRAW_ROLE to call this function
     * @dev Emits WithdrawNativeToken event on successful withdrawal
     * @dev Follows checks-effects-interactions pattern for security
     */
    function withdrawNativeToken(uint256 _amount, address _receiver) external nonReentrant {
        if (!_getPaymentsVaultStorage().nvmConfig.hasRole(msg.sender, WITHDRAW_ROLE)) {
            revert InvalidRole(msg.sender, WITHDRAW_ROLE);
        }

        // Emit event before external call to follow checks-effects-interactions pattern
        emit WithdrawNativeToken(msg.sender, _receiver, _amount);

        // Skip transfer if amount is 0
        if (_amount > 0) {
            (bool sent,) = _receiver.call{value: _amount}('');
            if (!sent) revert FailedToSendNativeToken();
        }
    }

    /**
     * @notice Records a deposit of ERC20 tokens to the vault
     * @param _erc20TokenAddress Address of the ERC20 token contract
     * @param _amount Amount of tokens being deposited
     * @param _from Original sender of the tokens
     * @dev Caller must have DEPOSITOR_ROLE to call this function
     * @dev Emits ReceivedERC20 event on successful deposit
     * @dev This function only records the deposit event; actual token transfer must be done separately
     */
    function depositERC20(address _erc20TokenAddress, uint256 _amount, address _from) external nonReentrant {
        if (!_getPaymentsVaultStorage().nvmConfig.hasRole(msg.sender, DEPOSITOR_ROLE)) {
            revert InvalidRole(msg.sender, DEPOSITOR_ROLE);
        }
        emit ReceivedERC20(_erc20TokenAddress, _from, _amount);
    }

    /**
     * @notice Withdraws ERC20 tokens from the vault to a specified receiver
     * @param _erc20TokenAddress Address of the ERC20 token contract
     * @param _amount Amount of tokens to withdraw
     * @param _receiver Address to receive the withdrawn tokens
     * @dev Caller must have WITHDRAW_ROLE to call this function
     * @dev Emits WithdrawERC20 event on successful withdrawal
     * @dev Follows checks-effects-interactions pattern for security
     */
    function withdrawERC20(address _erc20TokenAddress, uint256 _amount, address _receiver) external nonReentrant {
        if (!_getPaymentsVaultStorage().nvmConfig.hasRole(msg.sender, WITHDRAW_ROLE)) {
            revert InvalidRole(msg.sender, WITHDRAW_ROLE);
        }

        // Emit event before external call to follow checks-effects-interactions pattern
        emit WithdrawERC20(_erc20TokenAddress, msg.sender, _receiver, _amount);

        // Skip transfer if amount is 0
        if (_amount > 0) {
            IERC20 token = IERC20(_erc20TokenAddress);
            // Use transfer instead of transferFrom since we're sending from our own balance
            token.transfer(_receiver, _amount);
        }
    }

    /**
     * @notice Gets the current balance of native tokens (ETH) in the vault
     * @return balance The current native token balance
     */
    function getBalanceNativeToken() external view returns (uint256 balance) {
        return address(this).balance;
    }

    /**
     * @notice Gets the current balance of a specific ERC20 token in the vault
     * @param _erc20TokenAddress Address of the ERC20 token contract
     * @return balance The current token balance
     */
    function getBalanceERC20(address _erc20TokenAddress) external view returns (uint256 balance) {
        IERC20 token = IERC20(_erc20TokenAddress);
        return token.balanceOf(address(this));
    }

    /**
     * @dev Internal helper function to access the contract's namespaced storage
     * @return $ Reference to the contract's PaymentsVaultStorage struct
     * @dev Uses ERC-7201 namespaced storage pattern to safely access storage
     * @dev Uses inline assembly with memory-safe tag to directly access the storage slot
     */
    function _getPaymentsVaultStorage() internal pure returns (PaymentsVaultStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            $.slot := PAYMENTS_VAULT_STORAGE_LOCATION
        }
    }
}
