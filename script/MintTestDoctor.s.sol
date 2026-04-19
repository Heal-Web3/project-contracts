// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import {Script} from "forge-std/Script.sol";
// import {console} from "forge-std/console.sol";
// import {HealDoctorNFT} from "../src/HealDoctorNFT.sol";
// import {HealTypes} from "../src/HealTypes.sol";
// import {HelperConfig} from "./utils/HelperConfig.s.sol";

// /**
//  * @title MintTestDoctor
//  * @dev Script to mint test doctor NFTs for demo purposes
//  */
// contract MintTestDoctor is Script {
//     function run() external returns (uint256) {
//         HelperConfig helperConfig = new HelperConfig();
//         HelperConfig.NetworkConfig memory config = helperConfig.activeNetworkConfig();
        
//         address nftAddress = vm.envAddress("DOCTOR_NFT_ADDRESS");
        
//         // Test doctor data
//         string memory licenseNumber = "LIC-2024-001";
//         string memory fullName = "Dr. Jane Smith";
//         string memory specialty = "Cardiology";
        
//         console.log("========================================");
//         console.log("Minting Test Doctor NFT");
//         console.log("========================================");
//         console.log("Contract:", nftAddress);
//         console.log("License:", licenseNumber);
//         console.log("Name:", fullName);
//         console.log("Specialty:", specialty);
//         console.log("========================================");
        
//         vm.startBroadcast(config.deployerKey);
        
//         HealDoctorNFT doctorNFT = HealDoctorNFT(nftAddress);
        
//         // Check if already registered
//         try doctorNFT.getDoctorByAddress(vm.addr(config.deployerKey)) returns (uint256 existingTokenId) {
//             console.log("");
//             console.log("⚠️  Doctor already registered with token ID:", existingTokenId);
            
//             // Show existing info
//             HealTypes.Doctor memory existing = doctorNFT.getDoctorInfo(existingTokenId);
//             console.log("Existing License:", existing.licenseNumber);
//             console.log("Existing Name:", existing.fullName);
//             console.log("Active:", existing.isActive);
            
//             vm.stopBroadcast();
//             return existingTokenId;
//         } catch {
//             // Not registered, proceed with minting
//             console.log("");
//             console.log("Minting new NFT...");
//             uint256 tokenId = doctorNFT.mintDoctorNFT(licenseNumber, fullName, specialty);
            
//             vm.stopBroadcast();
            
//             console.log("✓ NFT minted successfully!");
//             console.log("Token ID:", tokenId);
//             console.log("Owner:", doctorNFT.ownerOf(tokenId));
//             console.log("Active:", doctorNFT.isDoctorActive(tokenId));
            
//             return tokenId;
//         }
//     }
// }

// /**
//  * @title MintMultipleDoctors
//  * @dev Script to mint multiple test doctors for comprehensive testing
//  */
// contract MintMultipleDoctors is Script {
//     struct DoctorData {
//         string licenseNumber;
//         string fullName;
//         string specialty;
//         uint256 privateKey;
//     }
    
//     function run() external {
//         HelperConfig helperConfig = new HelperConfig();
//         HelperConfig.NetworkConfig memory config = helperConfig.activeNetworkConfig();
        
//         address nftAddress = vm.envAddress("DOCTOR_NFT_ADDRESS");
//         HealDoctorNFT doctorNFT = HealDoctorNFT(nftAddress);
        
//         // Test doctor dataset
//         DoctorData[] memory doctors = new DoctorData[](5);
//         doctors[0] = DoctorData("LIC-001", "Dr. Alice Johnson", "Cardiology", 0x1111);
//         doctors[1] = DoctorData("LIC-002", "Dr. Bob Williams", "Neurology", 0x2222);
//         doctors[2] = DoctorData("LIC-003", "Dr. Carol Davis", "Pediatrics", 0x3333);
//         doctors[3] = DoctorData("LIC-004", "Dr. David Brown", "Oncology", 0x4444);
//         doctors[4] = DoctorData("LIC-005", "Dr. Emma Wilson", "Dermatology", 0x5555);
        
//         console.log("========================================");
//         console.log("Minting Multiple Test Doctors");
//         console.log("========================================");
        
//         for (uint256 i = 0; i < doctors.length; i++) {
//             // Use different signer for each doctor
//             vm.startBroadcast(doctors[i].privateKey);
            
//             try doctorNFT.getDoctorByAddress(vm.addr(doctors[i].privateKey)) returns (uint256 existingTokenId) {
//                 console.log("Doctor", i+1, "already registered. Token ID:", existingTokenId);
//             } catch {
//                 uint256 tokenId = doctorNFT.mintDoctorNFT(
//                     doctors[i].licenseNumber,
//                     doctors[i].fullName,
//                     doctors[i].specialty
//                 );
//                 console.log("✓ Minted Doctor", i+1, "Token ID:", tokenId);
//             }
            
//             vm.stopBroadcast();
//         }
        
//         console.log("========================================");
//         console.log("Total Doctors Registered:", doctorNFT.totalDoctors());
//         console.log("========================================");
//     }
// }



pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HealDoctorNFT} from "../src/HealDoctorNFT.sol";
import {HealTypes} from "../src/HealTypes.sol";
import {HelperConfig} from "./utils/HelperConfig.s.sol";

/**
 * @title MintTestDoctor
 * @dev Script to mint test doctor NFTs for demo purposes
 */
contract MintTestDoctor is Script {
    function run() external returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.activeNetworkConfig();
        
        address nftAddress = vm.envAddress("DOCTOR_NFT_ADDRESS");
        
        // Test doctor data
        string memory licenseNumber = "LIC-2024-001";
        string memory fullName = "Dr. Jane Smith";
        string memory specialty = "Cardiology";
        
        console.log("========================================");
        console.log("Minting Test Doctor NFT");
        console.log("========================================");
        console.log("Contract:", nftAddress);
        console.log("License:", licenseNumber);
        console.log("Name:", fullName);
        console.log("Specialty:", specialty);
        console.log("========================================");
        
        vm.startBroadcast(config.deployerKey);
        
        HealDoctorNFT doctorNFT = HealDoctorNFT(nftAddress);
        
        // Check if already registered
        try doctorNFT.getDoctorByAddress(vm.addr(config.deployerKey)) returns (uint256 existingTokenId) {
            console.log("");
            console.log("[WARNING] Doctor already registered with token ID:", existingTokenId);
            
            // Show existing info
            HealTypes.Doctor memory existing = doctorNFT.getDoctorInfo(existingTokenId);
            console.log("Existing License:", existing.licenseNumber);
            console.log("Existing Name:", existing.fullName);
            console.log("Active:", existing.isActive);
            
            vm.stopBroadcast();
            return existingTokenId;
        } catch {
            // Not registered, proceed with minting
            console.log("");
            console.log("Minting new NFT...");
            uint256 tokenId = doctorNFT.mintDoctorNFT(licenseNumber, fullName, specialty);
            
            vm.stopBroadcast();
            
            console.log("[SUCCESS] NFT minted successfully!");
            console.log("Token ID:", tokenId);
            console.log("Owner:", doctorNFT.ownerOf(tokenId));
            console.log("Active:", doctorNFT.isDoctorActive(tokenId));
            
            return tokenId;
        }
    }
}

/**
 * @title MintMultipleDoctors
 * @dev Script to mint multiple test doctors for comprehensive testing
 */
contract MintMultipleDoctors is Script {
    struct DoctorData {
        string licenseNumber;
        string fullName;
        string specialty;
        uint256 privateKey;
    }
    
    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.activeNetworkConfig();
        
        address nftAddress = vm.envAddress("DOCTOR_NFT_ADDRESS");
        HealDoctorNFT doctorNFT = HealDoctorNFT(nftAddress);
        
        // Test doctor dataset
        DoctorData[] memory doctors = new DoctorData[](5);
        doctors[0] = DoctorData("LIC-001", "Dr. Alice Johnson", "Cardiology", 0x1111);
        doctors[1] = DoctorData("LIC-002", "Dr. Bob Williams", "Neurology", 0x2222);
        doctors[2] = DoctorData("LIC-003", "Dr. Carol Davis", "Pediatrics", 0x3333);
        doctors[3] = DoctorData("LIC-004", "Dr. David Brown", "Oncology", 0x4444);
        doctors[4] = DoctorData("LIC-005", "Dr. Emma Wilson", "Dermatology", 0x5555);
        
        console.log("========================================");
        console.log("Minting Multiple Test Doctors");
        console.log("========================================");
        
        for (uint256 i = 0; i < doctors.length; i++) {
            // Use different signer for each doctor
            vm.startBroadcast(doctors[i].privateKey);
            
            try doctorNFT.getDoctorByAddress(vm.addr(doctors[i].privateKey)) returns (uint256 existingTokenId) {
                console.log("Doctor", i+1, "already registered. Token ID:", existingTokenId);
            } catch {
                uint256 tokenId = doctorNFT.mintDoctorNFT(
                    doctors[i].licenseNumber,
                    doctors[i].fullName,
                    doctors[i].specialty
                );
                console.log("[SUCCESS] Minted Doctor", i+1, "Token ID:", tokenId);
            }
            
            vm.stopBroadcast();
        }
        
        console.log("========================================");
        console.log("Total Doctors Registered:", doctorNFT.totalDoctors());
        console.log("========================================");
    }
}