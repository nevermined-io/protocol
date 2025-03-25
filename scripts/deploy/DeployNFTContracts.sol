// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../Constants.sol";
import {DeployConfig} from "./DeployConfig.sol";
import {INVMConfig} from "../../contracts/interfaces/INVMConfig.sol";
import {NFT1155Credits} from "../../contracts/token/NFT1155Credits.sol";

contract DeployNFTContracts is Script, DeployConfig {
    function run(address nvmConfigAddress) public returns (NFT1155Credits) {
        // Derive keys from mnemonic
        string memory mnemonic = vm.envString("MNEMONIC");
        uint256 ownerIndex = vm.envUint("OWNER_INDEX");
        uint256 governorIndex = vm.envUint("GOVERNOR_INDEX");
        uint256 ownerKey = vm.deriveKey(mnemonic, ownerIndex);
        uint256 governorKey = vm.deriveKey(mnemonic, governorIndex);
        INVMConfig nvmConfig = INVMConfig(nvmConfigAddress);
        
        // Deploy NFT1155Credits
        vm.startBroadcast(ownerKey);
        NFT1155Credits nftCredits = new NFT1155Credits();
        nftCredits.initialize(nvmConfigAddress, "Nevermined Credits", "NMCR");
        vm.stopBroadcast();
        
        // Register NFT1155Credits in NVMConfig (called by governor)
        // Using direct call to NVMConfig since registerContract is not in the interface
        vm.startBroadcast(governorKey);
        (bool success, ) = nvmConfigAddress.call(
            abi.encodeWithSignature(
                "registerContract(bytes32,address,uint256)",
                Constants.HASH_NFT1155CREDITS,
                address(nftCredits),
                1
            )
        );
        require(success, "Failed to register NFT1155Credits");
        vm.stopBroadcast();
        
        return nftCredits;
    }
}
