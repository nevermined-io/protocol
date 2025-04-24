// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {ITemplate} from '../interfaces/ITemplate.sol';

import {AccessManagedUUPSUpgradeable} from '../proxy/AccessManagedUUPSUpgradeable.sol';
import {AgreementsStore} from './AgreementsStore.sol';

/**
 * @title BaseTemplate
 * @author Nevermined
 * @notice Abstract base contract for all agreement templates in the Nevermined protocol
 * @dev BaseTemplate provides common functionality and storage for derived template contracts,
 *      establishing a consistent pattern for agreement creation and management. It implements
 *      the ITemplate interface and inherits AccessManagedUUPSUpgradeable for secure proxy
 *      upgrades. The contract uses ERC-7201 namespaced storage to ensure storage safety
 *      across upgrades and inheritance chains.
 *
 *      Derived templates (like FixedPaymentTemplate and FiatPaymentTemplate) extend this base
 *      contract to implement specific agreement workflows while maintaining consistent
 *      access patterns to the AgreementsStore and AssetsRegistry.
 */
abstract contract BaseTemplate is ITemplate, AccessManagedUUPSUpgradeable {
    // keccak256(abi.encode(uint256(keccak256("nevermined.basetemplate.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BASE_TEMPLATE_STORAGE_LOCATION =
        0xe216fc96f789fa9c96a1eaa661bfd7aef52752717013e765adce03d67eb13e00;

    /// @custom:storage-location erc7201:nevermined.basetemplate.storage
    struct BaseTemplateStorage {
        /// @notice Reference to the AgreementsStore contract for managing agreements
        AgreementsStore agreementStore;
        /// @notice Address of the AssetsRegistry contract for referencing digital assets
        address assetsRegistryAddress;
    }

    /**
     * @notice Internal function to get the contract's storage reference
     * @return $ Storage reference to the BaseTemplateStorage struct
     * @dev Uses ERC-7201 namespaced storage pattern for upgrade safety
     */
    function _getBaseTemplateStorage() internal pure returns (BaseTemplateStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            $.slot := BASE_TEMPLATE_STORAGE_LOCATION
        }
    }
}
