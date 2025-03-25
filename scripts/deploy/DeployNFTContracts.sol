// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../Constants.sol";
import {DeployConfig} from "./DeployConfig.sol";
import {INVMConfig} from "../../contracts/interfaces/INVMConfig.sol";
import {NFT1155Credits} from "../../contracts/token/NFT1155Credits.sol";

contract DeployNFTContracts is Script, DeployConfig {
    function run(address nvmConfigAddress) public returns (NFT1155Credits) {
        // Start broadcast with the signer provided by --mnemonics and --mnemonic-indexes
        vm.startBroadcast();
        
        // Get the current sender address to use as owner
        owner = msg.sender;
        
        // For governor operations, you would need to run a separate command with the governor index
        // This script assumes the owner is deploying the contracts
        INVMConfig nvmConfig = INVMConfig(nvmConfigAddress);
        
        // Deploy NFT1155Credits
        NFT1155Credits nftCredits = new NFT1155Credits();
        nftCredits.initialize(nvmConfigAddress, "Nevermined Credits", "NMCR");
        
        // Note: For registering contracts in NVMConfig, you would need to run a separate command
        // with the governor's mnemonic index, as that requires governor privileges
        
        vm.stopBroadcast();
        
        return nftCredits;
    }
}
