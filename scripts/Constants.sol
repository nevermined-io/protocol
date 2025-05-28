// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.30;

library Constants {
    // Contract name hashes for registration
    bytes32 constant HASH_ASSETS_REGISTRY = keccak256('AssetsRegistry');
    bytes32 constant HASH_AGREEMENTS_STORE = keccak256('AgreementsStore');
    bytes32 constant HASH_PAYMENTS_VAULT = keccak256('PaymentsVault');
    bytes32 constant HASH_NFT1155CREDITS = keccak256('NFT1155Credits');
    bytes32 constant HASH_NFT1155EXPIRABLECREDITS = keccak256('NFT1155ExpirableCredits');
    bytes32 constant HASH_LOCKPAYMENT_CONDITION = keccak256('LockPaymentCondition');
    bytes32 constant HASH_TRANSFERCREDITS_CONDITION = keccak256('TransferCreditsCondition');
    bytes32 constant HASH_DISTRIBUTEPAYMENTS_CONDITION = keccak256('DistributePaymentsCondition');
    bytes32 constant HASH_FIXED_PAYMENT_TEMPLATE = keccak256('FixedPaymentTemplate');

    // Roles
    bytes32 constant OWNER_ROLE = keccak256('NVM_CONFIG_OWNER');
    bytes32 constant GOVERNOR_ROLE = keccak256('NVM_GOVERNOR');
    bytes32 constant CONTRACT_TEMPLATE_ROLE = keccak256('NVM_CONTRACT_TEMPLATE');
    bytes32 constant CONTRACT_CONDITION_ROLE = keccak256('NVM_CONTRACT_CONDITION');
    bytes32 constant CREDITS_MINTER_ROLE = keccak256('CREDITS_MINTER_ROLE');
    bytes32 constant CREDITS_BURNER_ROLE = keccak256('CREDITS_MINTER_ROLE');

    // Default network fee
    uint256 constant DEFAULT_NVM_FEE_AMOUNT = 10000; // 1% by default
}
