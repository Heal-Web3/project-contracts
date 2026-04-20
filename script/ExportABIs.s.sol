// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract ExportABIs is Script {
    function run() external {
        console.log("Exporting ABIs...");
        
        // Read from out directory and copy to abi/
        string[] memory contracts = new string[](2);
        contracts[0] = "HealDoctorNFT";
        contracts[1] = "HealPrescriptionVerifier";
        
        for (uint i = 0; i < contracts.length; i++) {
            string memory sourcePath = string(abi.encodePacked(
                "out/", contracts[i], ".sol/", contracts[i], ".json"
            ));
            
            string memory destPath = string(abi.encodePacked(
                "abi/", contracts[i], ".json"
            ));
            
            // Read and write using Foundry cheatcodes
            string memory abiContent = vm.readFile(sourcePath);
            vm.writeFile(destPath, abiContent);
            
            console.log("Exported:", contracts[i]);
        }
        
        console.log("ABIs exported to ./abi/ directory");
    }
}