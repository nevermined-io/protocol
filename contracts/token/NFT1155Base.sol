// Copyright 2025 Nevermined AG.
// SPDX-License-Identifier: (Apache-2.0 AND CC-BY-4.0)
// Code is Apache-2.0 and docs are CC-BY-4.0
pragma solidity ^0.8.28;

import {IAsset} from '../interfaces/IAsset.sol';
import {CREDITS_BURN_PROOF_TYPEHASH, INFT1155} from '../interfaces/INFT1155.sol';
import {INVMConfig} from '../interfaces/INVMConfig.sol';
import {AccessManagedUUPSUpgradeable} from '../proxy/AccessManagedUUPSUpgradeable.sol';
import {ERC1155Upgradeable} from '@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol';
import {EIP712Upgradeable} from '@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol';

import {IAccessManager} from '@openzeppelin/contracts/access/manager/IAccessManager.sol';
import {IERC2981} from '@openzeppelin/contracts/interfaces/IERC2981.sol';

import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';

abstract contract NFT1155Base is ERC1155Upgradeable, INFT1155, EIP712Upgradeable, AccessManagedUUPSUpgradeable {
    /**
     * @notice Role allowing to mint credits
     */
    bytes32 public constant CREDITS_MINTER_ROLE = keccak256('CREDITS_MINTER_ROLE');

    /**
     * @notice Role allowing to burn credits
     */
    bytes32 public constant CREDITS_BURNER_ROLE = keccak256('CREDITS_BURNER_ROLE');

    /**
     * @notice Role allowing to transfer credits
     * @dev This role is not used in the current implementation
     */
    bytes32 public constant CREDITS_TRANSFER_ROLE = keccak256('CREDITS_TRANSFER_ROLE');

    // keccak256(abi.encode(uint256(keccak256("nevermined.nft1155base.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NFT1155_BASE_STORAGE_LOCATION =
        0x5dc28ad3de163acbf47a88082c92b50b1954ae8a6818aca0c0ef6cb317ac6500;

    /// @custom:storage-location erc7201:nevermined.nft1155base.storage
    struct NFT1155BaseStorage {
        INVMConfig nvmConfig;
        IAsset assetsRegistry;
        mapping(address sender => mapping(uint256 keyspace => uint256 nonce)) nonces;
    }

    // solhint-disable-next-line func-name-mixedcase
    /**
     * @notice Initializes the NFT1155Base contract with required dependencies
     * @param _nvmConfigAddress Address of the NVMConfig contract
     * @param _authority Address of the AccessManager contract
     * @param _assetsRegistryAddress Address of the AssetsRegistry contract
     * @dev Internal initialization function to be called by inheriting contracts
     */
    function __NFT1155Base_init(INVMConfig _nvmConfigAddress, IAccessManager _authority, IAsset _assetsRegistryAddress)
        internal
        onlyInitializing
    {
        NFT1155BaseStorage storage $ = _getNFT1155BaseStorage();

        __AccessManagedUUPSUpgradeable_init(address(_authority));
        __EIP712_init(type(NFT1155Base).name, '1');

        $.nvmConfig = _nvmConfigAddress;
        $.assetsRegistry = _assetsRegistryAddress;
    }

    /**
     * It mints credits for a plan.
     * @notice Only the owner of the plan or an account with the CREDITS_MINTER_ROLE can mint credits
     * @notice The payment plan must exists
     * @param _to the receiver of the credits
     * @param _planId the plan id
     * @param _amount the number of credits to mint
     * @param _data additional data to pass to the receiver
     */
    function mint(address _to, uint256 _planId, uint256 _amount, bytes memory _data) public virtual {
        NFT1155BaseStorage storage $ = _getNFT1155BaseStorage();

        IAsset.Plan memory plan = $.assetsRegistry.getPlan(_planId);
        if (plan.lastUpdated == 0) revert IAsset.PlanNotFound(_planId);

        // Only the owner of the plan or an account with the CREDITS_MINTER_ROLE can mint credits
        if (!$.nvmConfig.hasRole(msg.sender, CREDITS_MINTER_ROLE) && plan.owner != msg.sender) {
            revert INVMConfig.InvalidRole(msg.sender, CREDITS_MINTER_ROLE);
        }

        _mint(_to, _planId, _amount, _data);
    }

    /**
     * It mints credits in batch.
     * @notice Only the owner of the plan or an account with the CREDITS_MINTER_ROLE can mint credits
     * @notice The payment plan must exists
     * @param _to the receiver of the credits
     * @param _ids the plan ids
     * @param _values the number of credits to mint
     * @param _data additional data to pass to the receiver
     */
    function mintBatch(address _to, uint256[] memory _ids, uint256[] memory _values, bytes memory _data)
        public
        virtual
    {
        NFT1155BaseStorage storage $ = _getNFT1155BaseStorage();

        if (!$.nvmConfig.hasRole(msg.sender, CREDITS_MINTER_ROLE)) {
            revert INVMConfig.InvalidRole(msg.sender, CREDITS_MINTER_ROLE);
        }

        _mintBatch(_to, _ids, _values, _data);
    }

    /**
     * It burns/redeem credits for a plan.
     * @notice The redemption rules depend on the plan.credits.redemptionType
     * @param _from The address of the account that is getting the credits burned
     * @param _planId the plan id
     * @param _amount the number of credits to burn/redeem
     * @param _keyspace the keyspace of the nonce
     * @param _signature the signature of the credits burn proof
     */
    function burn(address _from, uint256 _planId, uint256 _amount, uint256 _keyspace, bytes calldata _signature)
        public
        virtual
    {
        NFT1155BaseStorage storage $ = _getNFT1155BaseStorage();

        IAsset.Plan memory plan = $.assetsRegistry.getPlan(_planId);
        require(plan.lastUpdated != 0, IAsset.PlanNotFound(_planId));
        require(
            _canRedeemCredits(_planId, plan.owner, plan.credits.redemptionType, msg.sender),
            InvalidRedemptionPermission(_planId, plan.credits.redemptionType, msg.sender)
        );

        uint256 creditsToRedeem =
            _creditsToRedeem(_planId, plan.credits.creditsType, _amount, plan.credits.minAmount, plan.credits.maxAmount);

        if (plan.credits.proofRequired) {
            uint256[] memory planIds = new uint256[](1);
            planIds[0] = _planId;

            CreditsBurnProofData memory proof =
                CreditsBurnProofData({keyspace: _keyspace, nonce: $.nonces[_from][_keyspace]++, planIds: planIds});

            bytes32 digest = hashCreditsBurnProof(proof);
            address signer = ECDSA.recover(digest, _signature);
            require(signer == _from, InvalidCreditsBurnProof(signer, _from));
        }

        _burn(_from, _planId, creditsToRedeem);
    }

    /**
     * It burns/redeem credits in batch.
     * @param _from the address of the account that is getting the credits burned
     * @param _ids the array of plan ids
     * @param _amounts the array of number of credits to burn/redeem
     * @param _keyspace the keyspace of the nonce
     * @param _signature the signature of the credits burn proof
     */
    function burnBatch(
        address _from,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        uint256 _keyspace,
        bytes calldata _signature
    ) public virtual {
        NFT1155BaseStorage storage $ = _getNFT1155BaseStorage();

        require(
            $.nvmConfig.hasRole(msg.sender, CREDITS_BURNER_ROLE),
            INVMConfig.InvalidRole(msg.sender, CREDITS_BURNER_ROLE)
        );

        uint256[] memory planIdsToVerify = new uint256[](_ids.length);
        uint256 counter;
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 planId = _ids[i];

            IAsset.Plan memory plan = $.assetsRegistry.getPlan(planId);

            _amounts[i] = _creditsToRedeem(
                planId, plan.credits.creditsType, _amounts[i], plan.credits.minAmount, plan.credits.maxAmount
            );

            if (plan.credits.proofRequired) {
                planIdsToVerify[counter++] = planId;
            }
        }

        // Set the array length
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            mstore(planIdsToVerify, counter)
        }

        if (planIdsToVerify.length > 0) {
            CreditsBurnProofData memory proof = CreditsBurnProofData({
                keyspace: _keyspace,
                nonce: $.nonces[_from][_keyspace]++,
                planIds: planIdsToVerify
            });
            bytes32 digest = hashCreditsBurnProof(proof);
            address signer = ECDSA.recover(digest, _signature);
            require(signer == _from, InvalidCreditsBurnProof(signer, _from));
        }

        _burnBatch(_from, _ids, _amounts);
    }

    /**
     * @notice Returns the next nonce for the given sender and keyspace
     * @param _sender The address of the account
     * @param _keyspaces The keyspaces for which to generate the nonce
     * @return nonces The next nonce values
     */
    function nextNonce(address _sender, uint256[] calldata _keyspaces)
        external
        view
        override
        returns (uint256[] memory nonces)
    {
        NFT1155BaseStorage storage $ = _getNFT1155BaseStorage();
        nonces = new uint256[](_keyspaces.length);
        for (uint256 i = 0; i < _keyspaces.length; i++) {
            nonces[i] = $.nonces[_sender][_keyspaces[i]];
        }
        return nonces;
    }

    function hashCreditsBurnProof(CreditsBurnProofData memory _proof) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(abi.encode(CREDITS_BURN_PROOF_TYPEHASH, _proof.keyspace, _proof.nonce, _proof.planIds))
        );
    }

    /**
     * It calculates the number of credits to redeem based on the plan and the credits type
     * @notice The credits to redeem depend on the plan.credits.creditsType
     * @param _planId the identifier of the plan
     * @param _creditsType the type of credits
     * @param _amount the number of credits requested to redeem
     * @param _min the minimum number of credits to redeem configured in the plan
     * @param _max the maximum number of credits to redeem configured in the plan
     * @return the number of credits to redeem
     */
    function _creditsToRedeem(
        uint256 _planId,
        IAsset.CreditsType _creditsType,
        uint256 _amount,
        uint256 _min,
        uint256 _max
    ) internal pure returns (uint256) {
        if (_creditsType == IAsset.CreditsType.DYNAMIC) {
            if (_amount < _min || _amount > _max) return _min;
            else return _amount;
        } else if (_creditsType == IAsset.CreditsType.FIXED) {
            return _min;
        } else if (_creditsType == IAsset.CreditsType.EXPIRABLE) {
            return 1;
        }
        revert IAsset.InvalidRedemptionAmount(_planId, _creditsType, _amount);
    }

    /**
     * @notice Internal function to check if an account can redeem credits for a plan
     * @param _planId Identifier of the plan
     * @param _owner Owner of the plan
     * @param _redemptionType Type of redemption allowed for the plan
     * @param _sender Address attempting to redeem credits
     * @return Boolean indicating whether the sender can redeem credits
     * @dev Checks redemption permissions based on the plan's redemption type
     */
    function _canRedeemCredits(uint256 _planId, address _owner, IAsset.RedemptionType _redemptionType, address _sender)
        internal
        view
        returns (bool)
    {
        NFT1155BaseStorage storage $ = _getNFT1155BaseStorage();

        if (_redemptionType == IAsset.RedemptionType.ONLY_GLOBAL_ROLE) {
            return $.nvmConfig.hasRole(_sender, CREDITS_BURNER_ROLE);
        } else if (_redemptionType == IAsset.RedemptionType.ONLY_OWNER) {
            return _sender == _owner;
        } else if (_redemptionType == IAsset.RedemptionType.ONLY_PLAN_ROLE) {
            return $.nvmConfig.hasRole(_sender, keccak256(abi.encode(_planId)));
        }
        return false;
    }

    //@solhint-disable-next-line
    function safeTransferFrom(
        address, /*from*/
        address, /*to*/
        uint256, /*id*/
        uint256, /*value*/
        bytes memory /*data*/
    ) public virtual override {
        revert INVMConfig.InvalidRole(msg.sender, CREDITS_TRANSFER_ROLE);
    }

    //@solhint-disable-next-line
    function safeBatchTransferFrom(
        address, /*from*/
        address, /*to*/
        uint256[] memory, /*ids*/
        uint256[] memory, /*values*/
        bytes memory /*data*/
    ) public virtual override {
        revert INVMConfig.InvalidRole(msg.sender, CREDITS_TRANSFER_ROLE);
    }

    /**
     * @notice Checks if the contract supports a given interface
     * @param interfaceId Interface identifier to check
     * @return Boolean indicating whether the interface is supported
     * @dev Supports ERC1155 and ERC2981 interfaces
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return ERC1155Upgradeable.supportsInterface(interfaceId) || interfaceId == type(IERC2981).interfaceId;
    }

    function _getNFT1155BaseStorage() internal pure returns (NFT1155BaseStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            $.slot := NFT1155_BASE_STORAGE_LOCATION
        }
    }
}
