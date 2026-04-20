// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HealDoctorNFT} from "../src/HealDoctorNFT.sol";
import {HelperConfig} from "./utils/HelperConfig.s.sol";

contract ConfigureRegulator is Script {
    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        
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