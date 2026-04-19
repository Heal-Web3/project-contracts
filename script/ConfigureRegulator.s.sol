// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import {Script} from "forge-std/Script.sol";
// import {console} from "forge-std/console.sol";
// import {HealDoctorNFT} from "../src/HealDoctorNFT.sol";
// import {HelperConfig} from "./utils/HelperConfig.s.sol";

// /**
//  * @title ConfigureRegulator
//  * @dev Script to update regulator address in HealDoctorNFT contract
//  */
// contract ConfigureRegulator is Script {
//     function run() external {
//         HelperConfig helperConfig = new HelperConfig();
//         HelperConfig.NetworkConfig memory config = helperConfig.activeNetworkConfig();
        
//         // Get contract address from environment or user input
//         address nftAddress = vm.envAddress("DOCTOR_NFT_ADDRESS");
//         address newRegulator = vm.envAddress("NEW_REGULATOR_ADDRESS");
        
//         console.log("========================================");
//         console.log("Configuring Regulator");
//         console.log("========================================");
//         console.log("NFT Contract:", nftAddress);
//         console.log("Current Regulator:", HealDoctorNFT(nftAddress).regulator());
//         console.log("New Regulator:", newRegulator);
//         console.log("========================================");
        
//         vm.startBroadcast(config.deployerKey);
        
//         HealDoctorNFT doctorNFT = HealDoctorNFT(nftAddress);
//         doctorNFT.setRegulator(newRegulator);
        
//         vm.stopBroadcast();
        
//         console.log("✓ Regulator updated successfully!");
//         console.log("New Regulator:", doctorNFT.regulator());
//     }
// }

// /**
//  * @title GetRegulatorInfo
//  * @dev Script to view current regulator configuration
//  */
// contract GetRegulatorInfo is Script {
//     function run() external view {
//         address nftAddress = vm.envAddress("DOCTOR_NFT_ADDRESS");
//         HealDoctorNFT doctorNFT = HealDoctorNFT(nftAddress);
        
//         console.log("========================================");
//         console.log("Regulator Information");
//         console.log("========================================");
//         console.log("NFT Contract:", nftAddress);
//         console.log("Regulator:", doctorNFT.regulator());
//         console.log("Owner:", doctorNFT.owner());
//         console.log("========================================");
//     }
// }



pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HealDoctorNFT} from "../src/HealDoctorNFT.sol";
import {HelperConfig} from "./utils/HelperConfig.s.sol";

/**
 * @title ConfigureRegulator
 * @dev Script to update regulator address in HealDoctorNFT contract
 */
contract ConfigureRegulator is Script {
    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.activeNetworkConfig();
        
        // Get contract address from environment or user input
        address nftAddress = vm.envAddress("DOCTOR_NFT_ADDRESS");
        address newRegulator = vm.envAddress("NEW_REGULATOR_ADDRESS");
        
        console.log("========================================");
        console.log("Configuring Regulator");
        console.log("========================================");
        console.log("NFT Contract:", nftAddress);
        console.log("Current Regulator:", HealDoctorNFT(nftAddress).regulator());
        console.log("New Regulator:", newRegulator);
        console.log("========================================");
        
        vm.startBroadcast(config.deployerKey);
        
        HealDoctorNFT doctorNFT = HealDoctorNFT(nftAddress);
        doctorNFT.setRegulator(newRegulator);
        
        vm.stopBroadcast();
        
        console.log("[SUCCESS] Regulator updated successfully!");
        console.log("New Regulator:", doctorNFT.regulator());
    }
}

/**
 * @title GetRegulatorInfo
 * @dev Script to view current regulator configuration
 */
contract GetRegulatorInfo is Script {
    function run() external view {
        address nftAddress = vm.envAddress("DOCTOR_NFT_ADDRESS");
        HealDoctorNFT doctorNFT = HealDoctorNFT(nftAddress);
        
        console.log("========================================");
        console.log("Regulator Information");
        console.log("========================================");
        console.log("NFT Contract:", nftAddress);
        console.log("Regulator:", doctorNFT.regulator());
        console.log("Owner:", doctorNFT.owner());
        console.log("========================================");
    }
}