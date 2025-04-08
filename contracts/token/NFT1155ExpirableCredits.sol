// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {INVMConfig} from "../interfaces/INVMConfig.sol";
import {IAsset} from "../interfaces/IAsset.sol";
import {NFT1155Base} from "./NFT1155Base.sol";

contract NFT1155ExpirableCredits is NFT1155Base {
    struct MintedCredits {
        uint256 amountMinted; // uint64
        uint256 expirationSecs;
        uint256 mintTimestamp;
        bool isMintOps; // true means mint, false means burn
    }

    mapping(bytes32 => MintedCredits[]) internal _credits;

    /// The lentgh of the ids and values arrays must be the same
    /// @param idsLength The length of the ids array
    /// @param valuesLength The length of the values array
    error InvalidLength(uint256 idsLength, uint256 valuesLength);

    function initialize(
        address _nvmConfigAddress,
        address _assetsRegistryAddress,
        string memory, /*_name*/
        string memory /*_symbol*/
    ) public virtual initializer {
        ERC1155Upgradeable.__ERC1155_init("");

        nvmConfig = INVMConfig(_nvmConfigAddress);
        assetsRegistry = IAsset(_assetsRegistryAddress);

        __Ownable_init(msg.sender);
    }

    function mint(address _to, uint256 _planId, uint256 _value, bytes memory _data) public virtual override {
        mint(_to, _planId, _value, 0, _data);
    }

    function mint(address _to, uint256 _planId, uint256 _value, uint256 _secsDuration, bytes memory _data)
        public
        virtual
    {
        bytes32 _key = _getTokenKey(_to, _planId);

        _credits[_key].push(MintedCredits(_value, _secsDuration, block.timestamp, true));

        super.mint(_to, _planId, _value, _data);
    }

    function mintBatch(address _to, uint256[] memory _ids, uint256[] memory _values, bytes memory _data)
        public
        virtual
        override
    {
        uint256 _length = _ids.length;
        uint256[] memory _secsDurations = new uint256[](_length);
        mintBatch(_to, _ids, _values, _secsDurations, _data);
    }

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

    function burn(address _from, uint256 _planId, uint256 _value) public virtual override {
        if (!nvmConfig.hasRole(msg.sender, CREDITS_BURNER_ROLE)) {
            revert InvalidRole(msg.sender, CREDITS_BURNER_ROLE);
        }

        bytes32 _key = _getTokenKey(_from, _planId);
        uint256 _pendingToBurn = _value;

        uint256 _numEntries = _credits[_key].length;
        for (uint256 index = 0; index < _numEntries; index++) {
            MintedCredits memory entry = _credits[_key][index];

            if (entry.expirationSecs == 0 || block.timestamp < (entry.mintTimestamp + entry.expirationSecs)) {
                if (_pendingToBurn <= entry.amountMinted) {
                    _credits[_key].push(MintedCredits(_pendingToBurn, entry.expirationSecs, block.timestamp, false));
                    break;
                } else {
                    _pendingToBurn -= entry.amountMinted;
                    _credits[_key].push(MintedCredits(entry.amountMinted, entry.expirationSecs, block.timestamp, false));
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

    function balanceOf(address _owner, uint256 _planId) public view virtual override returns (uint256) {
        bytes32 _key = _getTokenKey(_owner, _planId);
        uint256 _amountBurned;
        uint256 _amountMinted;

        uint256 _length = _credits[_key].length;
        for (uint256 index = 0; index < _length; index++) {
            if (
                _credits[_key][index].mintTimestamp > 0
                    && (
                        _credits[_key][index].expirationSecs == 0
                            || block.timestamp < (_credits[_key][index].mintTimestamp + _credits[_key][index].expirationSecs)
                    )
            ) {
                if (_credits[_key][index].isMintOps) _amountMinted += _credits[_key][index].amountMinted;
                else _amountBurned += _credits[_key][index].amountMinted;
            }
        }

        if (_amountBurned >= _amountMinted) return 0;
        else return _amountMinted - _amountBurned;
    }

    function balanceOfBatch(address[] memory _owners, uint256[] memory _ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        uint256 _length = _ids.length;
        if (_length != _owners.length) revert InvalidLength(_length, _owners.length);

        uint256[] memory _balances = new uint256[](_length);
        for (uint256 i = 0; i < _length; i++) {
            _balances[i] = balanceOf(_owners[i], _ids[i]);
        }
        return _balances;
    }

    function whenWasMinted(address _owner, uint256 _planId) public view returns (uint256[] memory) {
        bytes32 _key = _getTokenKey(_owner, _planId);
        uint256 _length = _credits[_key].length;

        uint256[] memory _whenMinted = new uint256[](_length);
        for (uint256 index = 0; index < _length; index++) {
            _whenMinted[index] = _credits[_key][index].mintTimestamp;
        }
        return _whenMinted;
    }

    function getMintedEntries(address _owner, uint256 _planId) public view returns (MintedCredits[] memory) {
        return _credits[_getTokenKey(_owner, _planId)];
    }

    function _getTokenKey(address _account, uint256 _planId) internal pure returns (bytes32) {
        return keccak256(abi.encode(_account, _planId));
    }
}
