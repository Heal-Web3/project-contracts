// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HealDoctorNFT} from "../src/HealDoctorNFT.sol";
import {HealTypes} from "../src/HealTypes.sol";
import {HelperConfig} from "./utils/HelperConfig.s.sol";

contract MintTestDoctor is Script {
    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        
        address nftAddress = vm.envAddress("DOCTOR_NFT_ADDRESS");
        address doctorAddress = vm.addr(config.deployerKey);
        
        HealTypes.DoctorRegistration memory registration = HealTypes.DoctorRegistration({
            licenseNumber: "LIC-2024-001",
            fullName: "Dr. Jane Smith",
            specialty: "Cardiology"
        });
        
        console.log("========================================");
        console.log("Minting Test Doctor NFT");
        console.log("========================================");
        console.log("Contract:", nftAddress);
        console.log("Doctor Address:", doctorAddress);
        console.log("License:", registration.licenseNumber);
        console.log("Name:", registration.fullName);
        console.log("Specialty:", registration.specialty);
        console.log("========================================");
        
        vm.startBroadcast(config.deployerKey);
        
        HealDoctorNFT doctorNFT = HealDoctorNFT(nftAddress);
        
        try doctorNFT.getDoctorByAddress(doctorAddress) returns (uint256 existingTokenId) {
            console.log("");
            console.log("[WARNING] Doctor already registered with token ID:", existingTokenId);
            
            HealTypes.Doctor memory existing = doctorNFT.getDoctorInfo(existingTokenId);
            console.log("Existing License:", existing.licenseNumber);
            console.log("Existing Name:", existing.fullName);
            console.log("Active:", existing.isActive);
        } catch {
            console.log("");
            console.log("Minting new NFT...");
            uint256 tokenId = doctorNFT.mintDoctorNFT(doctorAddress, registration);
            console.log("[SUCCESS] NFT minted successfully!");
            console.log("Token ID:", tokenId);
            console.log("Owner:", doctorNFT.ownerOf(tokenId));
            console.log("Active:", doctorNFT.isDoctorActive(tokenId));
        }
        
        vm.stopBroadcast();
    }
}