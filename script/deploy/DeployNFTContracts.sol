// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../Constants.sol";
import {DeployConfig} from "./DeployConfig.sol";
import {INVMConfig} from "../../contracts/interfaces/INVMConfig.sol";
import {NFT1155Credits} from "../../contracts/token/NFT1155Credits.sol";

contract DeployNFTContracts is Script, DeployConfig {
    function run(address nvmConfigAddress) public returns (NFT1155Credits) {
        uint256 deployerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        uint256 governorPrivateKey = vm.envUint("GOVERNOR_PRIVATE_KEY");
        INVMConfig nvmConfig = INVMConfig(nvmConfigAddress);
        
        // Deploy NFT1155Credits
        vm.startBroadcast(deployerPrivateKey);
        NFT1155Credits nftCredits = new NFT1155Credits();
        nftCredits.initialize(nvmConfigAddress);
        vm.stopBroadcast();
        
        // Register NFT1155Credits in NVMConfig (called by governor)
        vm.startBroadcast(governorPrivateKey);
        nvmConfig.registerContract(Constants.HASH_NFT1155CREDITS, address(nftCredits), 1);
        vm.stopBroadcast();
        
        return nftCredits;
    }
}
