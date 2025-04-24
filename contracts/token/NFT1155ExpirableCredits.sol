// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {IAsset} from '../interfaces/IAsset.sol';
import {INVMConfig} from '../interfaces/INVMConfig.sol';
import {NFT1155Base} from './NFT1155Base.sol';
import {ERC1155Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';

contract NFT1155ExpirableCredits is NFT1155Base {
    // keccak256(abi.encode(uint256(keccak256("nevermined.nft1155expirablecredits.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NFT1155_EXPIRABLE_CREDITS_STORAGE_LOCATION =
        0xad13115e659bb74b20198931946852537615445c0d1e91655e57181f5cb10400;

    struct MintedCredits {
        uint256 amountMinted; // uint64
        uint256 expirationSecs;
        uint256 mintTimestamp;
        bool isMintOps; // true means mint, false means burn
    }

    /// @custom:storage-location erc7201:nevermined.nft1155expirablecredits.storage
    struct NFT1155ExpirableCreditsStorage {
        mapping(bytes32 => MintedCredits[]) credits;
    }

    /**
     * @notice Initializes the NFT1155ExpirableCredits contract with required dependencies
     * @param _nvmConfigAddress Address of the NVMConfig contract
     * @param _authority Address of the AccessManager contract
     * @param _assetsRegistryAddress Address of the AssetsRegistry contract
     * @dev Also accepts unused name and symbol parameters for compatibility
     */
    function initialize(
        INVMConfig _nvmConfigAddress,
        IAccessManager _authority,
        IAsset _assetsRegistryAddress,
        string memory, // name
        string memory // symbol
    ) external virtual initializer {
        ERC1155Upgradeable.__ERC1155_init('');
        __NFT1155Base_init(_nvmConfigAddress, _authority, _assetsRegistryAddress);
    }

    /**
     * @notice Mints credits for a specific plan
     * @param _to Address that will receive the credits
     * @param _planId Identifier of the plan
     * @param _value Amount of credits to mint
     * @param _data Additional data to pass to the receiver
     */
    function mint(address _to, uint256 _planId, uint256 _value, bytes memory _data) public virtual override {
        mint(_to, _planId, _value, 0, _data);
    }

    /**
     * @notice Mints credits with an expiration duration for a specific plan
     * @param _to Address that will receive the credits
     * @param _planId Identifier of the plan
     * @param _value Amount of credits to mint
     * @param _secsDuration Duration in seconds before the credits expire (0 for non-expiring)
     * @param _data Additional data to pass to the receiver
     * @dev Records the minting operation with timestamp and expiration information
     */
    function mint(address _to, uint256 _planId, uint256 _value, uint256 _secsDuration, bytes memory _data)
        public
        virtual
    {
        bytes32 _key = _getTokenKey(_to, _planId);

        _getNFT1155ExpirableCreditsStorage().credits[_key].push(
            MintedCredits(_value, _secsDuration, block.timestamp, true)
        );

        super.mint(_to, _planId, _value, _data);
    }

    /**
     * Mints credits for a multiple plans
     * @param _to the address to mint credits to
     * @param _ids the array of plan identifiers
     * @param _values the array of amounts to mint
     * @param _data Additional data to pass to the receiver
     */
    function mintBatch(address _to, uint256[] memory _ids, uint256[] memory _values, bytes memory _data)
        public
        virtual
        override
    {
        uint256 _length = _ids.length;
        uint256[] memory _secsDurations = new uint256[](_length);
        mintBatch(_to, _ids, _values, _secsDurations, _data);
    }

    /**
     * @notice Mints multiple credits with expiration durations for multiple plans
     * @param _to Address that will receive the credits
     * @param _ids Array of plan identifiers
     * @param _values Array of credit amounts to mint
     * @param _secsDurations Array of durations in seconds before credits expire
     * @param _data Additional data to pass to the receiver
     * @dev Validates array lengths match before minting each credit batch
     */
    function mintBatch(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _values,
        uint256[] memory _secsDurations,
        bytes memory _data
    ) public virtual {
        uint256 _length = _ids.length;
        if (_length != _values.length) revert InvalidLength(_length, _values.length);
        if (_length != _secsDurations.length) revert InvalidLength(_length, _secsDurations.length);

        for (uint256 i = 0; i < _length; i++) {
            mint(_to, _ids[i], _values[i], _secsDurations[i], _data);
        }
    }

    /**
     * Burns credits for a specific plan
     * @param _from the address to burn credits from
     * @param _planId the plan identifier
     * @param _value the number of credits to burn
     */
    function burn(address _from, uint256 _planId, uint256 _value) public virtual override {
        NFT1155ExpirableCreditsStorage storage $ = _getNFT1155ExpirableCreditsStorage();

        if (!_getNFT1155BaseStorage().nvmConfig.hasRole(msg.sender, CREDITS_BURNER_ROLE)) {
            revert INVMConfig.InvalidRole(msg.sender, CREDITS_BURNER_ROLE);
        }

        bytes32 _key = _getTokenKey(_from, _planId);
        uint256 _pendingToBurn = _value;

        uint256 _numEntries = $.credits[_key].length;
        for (uint256 index = 0; index < _numEntries; index++) {
            MintedCredits memory entry = $.credits[_key][index];

            if (entry.expirationSecs == 0 || block.timestamp < (entry.mintTimestamp + entry.expirationSecs)) {
                if (_pendingToBurn <= entry.amountMinted) {
                    $.credits[_key].push(MintedCredits(_pendingToBurn, entry.expirationSecs, block.timestamp, false));
                    break;
                } else {
                    _pendingToBurn -= entry.amountMinted;
                    $.credits[_key].push(
                        MintedCredits(entry.amountMinted, entry.expirationSecs, block.timestamp, false)
                    );
                }
            }
        }

        super.burn(_from, _planId, _value);
    }

    function burnBatch(address _from, uint256[] memory _ids, uint256[] memory _values) public virtual override {
        uint256 _length = _ids.length;
        if (_length != _values.length) revert InvalidLength(_length, _values.length);

        for (uint256 i = 0; i < _length; i++) {
            burn(_from, _ids[i], _values[i]);
        }
    }

    /**
     * @notice Gets the current balance of credits for a specific owner and plan
     * @param _owner Address of the credits owner
     * @param _planId Identifier of the plan
     * @return The current balance of non-expired credits
     * @dev Calculates balance by tracking minted and burned credits, considering expiration
     */
    function balanceOf(address _owner, uint256 _planId) public view virtual override returns (uint256) {
        NFT1155ExpirableCreditsStorage storage $ = _getNFT1155ExpirableCreditsStorage();

        bytes32 _key = _getTokenKey(_owner, _planId);
        uint256 _amountBurned;
        uint256 _amountMinted;

        uint256 _length = $.credits[_key].length;
        for (uint256 index = 0; index < _length; index++) {
            if (
                $.credits[_key][index].mintTimestamp > 0
                    && (
                        $.credits[_key][index].expirationSecs == 0
                            || block.timestamp < ($.credits[_key][index].mintTimestamp + $.credits[_key][index].expirationSecs)
                    )
            ) {
                if ($.credits[_key][index].isMintOps) _amountMinted += $.credits[_key][index].amountMinted;
                else _amountBurned += $.credits[_key][index].amountMinted;
            }
        }

        if (_amountBurned >= _amountMinted) return 0;
        else return _amountMinted - _amountBurned;
    }

    /**
     * @notice Gets the timestamps when credits were minted for a specific owner and plan
     * @param _owner Address of the credits owner
     * @param _planId Identifier of the plan
     * @return Array of timestamps when credits were minted
     */
    function whenWasMinted(address _owner, uint256 _planId) external view returns (uint256[] memory) {
        NFT1155ExpirableCreditsStorage storage $ = _getNFT1155ExpirableCreditsStorage();

        bytes32 _key = _getTokenKey(_owner, _planId);
        uint256 _length = $.credits[_key].length;

        uint256[] memory _whenMinted = new uint256[](_length);
        for (uint256 index = 0; index < _length; index++) {
            _whenMinted[index] = $.credits[_key][index].mintTimestamp;
        }
        return _whenMinted;
    }

    /**
     * @notice Gets all minted credit entries for a specific owner and plan
     * @param _owner Address of the credits owner
     * @param _planId Identifier of the plan
     * @return Array of MintedCredits structures containing detailed minting information
     */
    function getMintedEntries(address _owner, uint256 _planId) external view returns (MintedCredits[] memory) {
        return _getNFT1155ExpirableCreditsStorage().credits[_getTokenKey(_owner, _planId)];
    }

    /**
     * @notice Internal function to generate a unique key for tracking credits
     * @param _account Address of the credits owner
     * @param _planId Identifier of the plan
     * @return A unique bytes32 key generated from the account and plan ID
     */
    function _getTokenKey(address _account, uint256 _planId) internal pure returns (bytes32) {
        return keccak256(abi.encode(_account, _planId));
    }

    function _getNFT1155ExpirableCreditsStorage() internal pure returns (NFT1155ExpirableCreditsStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            $.slot := NFT1155_EXPIRABLE_CREDITS_STORAGE_LOCATION
        }
    }
}
