// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HealDoctorNFT} from "../src/HealDoctorNFT.sol";
import {HealPrescriptionVerifier} from "../src/HealPrescriptionVerifier.sol";
import {HelperConfig} from "./utils/HelperConfig.s.sol";

contract DeployHeal is Script {
    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        
        console.log("========================================");
        console.log("Deploying Heal Protocol Contracts");
        console.log("========================================");
        console.log("Network Chain ID:", config.chainId);
        console.log("Regulator Address:", config.regulator);
        console.log("Deployer Address:", vm.addr(config.deployerKey));
        console.log("========================================");

        vm.startBroadcast(config.deployerKey);

        console.log("");
        console.log("Step 1: Deploying HealDoctorNFT...");
        HealDoctorNFT doctorNFT = new HealDoctorNFT(config.regulator);
        console.log("[SUCCESS] HealDoctorNFT deployed at:", address(doctorNFT));

        console.log("");
        console.log("Step 2: Deploying HealPrescriptionVerifier...");
        HealPrescriptionVerifier verifier = new HealPrescriptionVerifier(address(doctorNFT));
        console.log("[SUCCESS] HealPrescriptionVerifier deployed at:", address(verifier));

        vm.stopBroadcast();

        console.log("");
        console.log("========================================");
        console.log("Deployment Complete!");
        console.log("========================================");
        console.log("HealDoctorNFT:", address(doctorNFT));
        console.log("HealPrescriptionVerifier:", address(verifier));
        console.log("Regulator:", config.regulator);
        console.log("========================================");
    }
}