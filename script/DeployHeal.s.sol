// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import {Script} from "forge-std/Script.sol";
// import {console} from "forge-std/console.sol";
// import {HealDoctorNFT} from "../src/HealDoctorNFT.sol";
// import {HealPrescriptionVerifier} from "../src/HealPrescriptionVerifier.sol";
// import {HelperConfig} from "./utils/HelperConfig.s.sol";

// /**
//  * @title DeployHeal
//  * @dev Deploys Heal protocol contracts to specified network
//  * @notice Deploys in order: HealDoctorNFT -> HealPrescriptionVerifier
//  */
// contract DeployHeal is Script {
//     // Contract instances
//     HealDoctorNFT public doctorNFT;
//     HealPrescriptionVerifier public verifier;
    
//     // Configuration
//     HelperConfig public helperConfig;
//     HelperConfig.NetworkConfig public config;

//     // Events for logging
//     event ContractsDeployed(
//         address indexed doctorNFT,
//         address indexed verifier,
//         address regulator,
//         uint256 chainId,
//         uint256 timestamp
//     );

//     function run() external returns (HealDoctorNFT, HealPrescriptionVerifier) {
//         // Get network configuration
//         helperConfig = new HelperConfig();
//         config = helperConfig.activeNetworkConfig();
        
//         // Log deployment start
//         console.log("========================================");
//         console.log("Deploying Heal Protocol Contracts");
//         console.log("========================================");
//         console.log("Network Chain ID:", config.chainId);
//         console.log("Regulator Address:", config.regulator);
//         console.log("Deployer Address:", vm.addr(config.deployerKey));
//         console.log("========================================");

//         // Start broadcasting transactions
//         vm.startBroadcast(config.deployerKey);

//         // Step 1: Deploy HealDoctorNFT
//         console.log("");
//         console.log("Step 1: Deploying HealDoctorNFT...");
//         doctorNFT = new HealDoctorNFT();
//         console.log("✓ HealDoctorNFT deployed at:", address(doctorNFT));

//         // Step 2: Set regulator if different from deployer
//         address deployer = vm.addr(config.deployerKey);
//         if (config.regulator != deployer && config.regulator != address(0)) {
//             console.log("");
//             console.log("Step 2: Setting regulator to:", config.regulator);
//             doctorNFT.setRegulator(config.regulator);
//             console.log("✓ Regulator set successfully");
//         } else {
//             console.log("");
//             console.log("Step 2: Deployer is regulator, skipping...");
//         }

//         // Step 3: Deploy HealPrescriptionVerifier
//         console.log("");
//         console.log("Step 3: Deploying HealPrescriptionVerifier...");
//         verifier = new HealPrescriptionVerifier(address(doctorNFT));
//         console.log("✓ HealPrescriptionVerifier deployed at:", address(verifier));

//         vm.stopBroadcast();

//         // Log deployment summary
//         console.log("");
//         console.log("========================================");
//         console.log("Deployment Complete!");
//         console.log("========================================");
//         console.log("HealDoctorNFT:", address(doctorNFT));
//         console.log("HealPrescriptionVerifier:", address(verifier));
//         console.log("Regulator:", config.regulator);
//         console.log("========================================");

//         // Emit event (for logging purposes)
//         emit ContractsDeployed(
//             address(doctorNFT),
//             address(verifier),
//             config.regulator,
//             config.chainId,
//             block.timestamp
//         );

//         // Save deployment addresses to file
//         saveDeploymentAddresses();

//         return (doctorNFT, verifier);
//     }

//     /**
//      * @dev Save deployed addresses to JSON file for frontend
//      */
//     function saveDeploymentAddresses() internal {
//         string memory chainName = getChainName(config.chainId);
        
//         string memory json = string(abi.encodePacked(
//             "{\n",
//             '  "network": "', chainName, '",\n',
//             '  "chainId": ', vm.toString(config.chainId), ',\n',
//             '  "deploymentTimestamp": ', vm.toString(block.timestamp), ',\n',
//             '  "contracts": {\n',
//             '    "HealDoctorNFT": "', vm.toString(address(doctorNFT)), '",\n',
//             '    "HealPrescriptionVerifier": "', vm.toString(address(verifier)), '"\n',
//             '  },\n',
//             '  "regulator": "', vm.toString(config.regulator), '"\n',
//             "}\n"
//         ));
        
//         // Create deployment artifacts directory if it doesn't exist
//         string memory dirPath = string(abi.encodePacked("deployments/", chainName));
//         vm.createDir(dirPath, true);
        
//         // Save to file
//         string memory filePath = string(abi.encodePacked(
//             dirPath, 
//             "/deployment-", 
//             vm.toString(block.timestamp), 
//             ".json"
//         ));
//         vm.writeFile(filePath, json);
        
//         // Also save as latest
//         string memory latestPath = string(abi.encodePacked(dirPath, "/latest.json"));
//         vm.writeFile(latestPath, json);
        
//         console.log("");
//         console.log("Deployment artifacts saved to:", filePath);
//     }

//     /**
//      * @dev Get human-readable chain name
//      */
//     function getChainName(uint256 chainId) internal pure returns (string memory) {
//         if (chainId == 1) return "mainnet";
//         if (chainId == 11155111) return "sepolia";
//         if (chainId == 31337) return "localhost";
//         return "unknown";
//     }

//     /**
//      * @dev Verify contracts on Etherscan (call separately after deployment)
//      */
//     function verify() external {
//         if (!config.verify) {
//             console.log("Verification skipped for this network");
//             return;
//         }
        
//         console.log("Verifying contracts on Etherscan...");
        
//         // Build verification commands
//         console.log("");
//         console.log("Run these commands to verify:");
//         console.log("");
//         console.log("forge verify-contract \\");
//         console.log("  --chain-id", config.chainId, "\\");
//         console.log("  --num-of-optimizations 200 \\");
//         console.log("  --compiler-version v0.8.20 \\");
//         console.log(" ", address(doctorNFT), "\\");
//         console.log("  src/HealDoctorNFT.sol:HealDoctorNFT");
//         console.log("");
//         console.log("forge verify-contract \\");
//         console.log("  --chain-id", config.chainId, "\\");
//         console.log("  --num-of-optimizations 200 \\");
//         console.log("  --compiler-version v0.8.20 \\");
//         console.log(" ", address(verifier), "\\");
//         console.log("  src/HealPrescriptionVerifier.sol:HealPrescriptionVerifier \\");
//         console.log("  --constructor-args $(cast abi-encode 'constructor(address)'", address(doctorNFT), ")");
//     }
// }

// /**
//  * @title DeployHealLocal
//  * @dev Deploys to local Anvil node for testing
//  */
// contract DeployHealLocal is DeployHeal {
//     function run() external returns (HealDoctorNFT, HealPrescriptionVerifier) {
//         // Override for local deployment with default Anvil values
//         return super.run();
//     }
// }




pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HealDoctorNFT} from "../src/HealDoctorNFT.sol";
import {HealPrescriptionVerifier} from "../src/HealPrescriptionVerifier.sol";
import {HelperConfig} from "./utils/HelperConfig.s.sol";

/**
 * @title DeployHeal
 * @dev Deploys Heal protocol contracts to specified network
 * @notice Deploys in order: HealDoctorNFT -> HealPrescriptionVerifier
 */
contract DeployHeal is Script {
    // Contract instances
    HealDoctorNFT public doctorNFT;
    HealPrescriptionVerifier public verifier;
    
    // Configuration
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public config;

    // Events for logging
    event ContractsDeployed(
        address indexed doctorNFT,
        address indexed verifier,
        address regulator,
        uint256 chainId,
        uint256 timestamp
    );

    function run() external returns (HealDoctorNFT, HealPrescriptionVerifier) {
        // Get network configuration
        helperConfig = new HelperConfig();
        config = helperConfig.activeNetworkConfig();
        
        // Log deployment start
        console.log("========================================");
        console.log("Deploying Heal Protocol Contracts");
        console.log("========================================");
        console.log("Network Chain ID:", config.chainId);
        console.log("Regulator Address:", config.regulator);
        console.log("Deployer Address:", vm.addr(config.deployerKey));
        console.log("========================================");

        // Start broadcasting transactions
        vm.startBroadcast(config.deployerKey);

        // Step 1: Deploy HealDoctorNFT
        console.log("");
        console.log("Step 1: Deploying HealDoctorNFT...");
        doctorNFT = new HealDoctorNFT();
        console.log("[SUCCESS] HealDoctorNFT deployed at:", address(doctorNFT));

        // Step 2: Set regulator if different from deployer
        address deployer = vm.addr(config.deployerKey);
        if (config.regulator != deployer && config.regulator != address(0)) {
            console.log("");
            console.log("Step 2: Setting regulator to:", config.regulator);
            doctorNFT.setRegulator(config.regulator);
            console.log("[SUCCESS] Regulator set successfully");
        } else {
            console.log("");
            console.log("Step 2: Deployer is regulator, skipping...");
        }

        // Step 3: Deploy HealPrescriptionVerifier
        console.log("");
        console.log("Step 3: Deploying HealPrescriptionVerifier...");
        verifier = new HealPrescriptionVerifier(address(doctorNFT));
        console.log("[SUCCESS] HealPrescriptionVerifier deployed at:", address(verifier));

        vm.stopBroadcast();

        // Log deployment summary
        console.log("");
        console.log("========================================");
        console.log("Deployment Complete!");
        console.log("========================================");
        console.log("HealDoctorNFT:", address(doctorNFT));
        console.log("HealPrescriptionVerifier:", address(verifier));
        console.log("Regulator:", config.regulator);
        console.log("========================================");

        // Emit event (for logging purposes)
        emit ContractsDeployed(
            address(doctorNFT),
            address(verifier),
            config.regulator,
            config.chainId,
            block.timestamp
        );

        // Save deployment addresses to file
        saveDeploymentAddresses();

        return (doctorNFT, verifier);
    }

    /**
     * @dev Save deployed addresses to JSON file for frontend
     */
    function saveDeploymentAddresses() internal {
        string memory chainName = getChainName(config.chainId);
        
        string memory json = string(abi.encodePacked(
            "{\n",
            '  "network": "', chainName, '",\n',
            '  "chainId": ', vm.toString(config.chainId), ',\n',
            '  "deploymentTimestamp": ', vm.toString(block.timestamp), ',\n',
            '  "contracts": {\n',
            '    "HealDoctorNFT": "', vm.toString(address(doctorNFT)), '",\n',
            '    "HealPrescriptionVerifier": "', vm.toString(address(verifier)), '"\n',
            '  },\n',
            '  "regulator": "', vm.toString(config.regulator), '"\n',
            "}\n"
        ));
        
        // Create deployment artifacts directory if it doesn't exist
        string memory dirPath = string(abi.encodePacked("deployments/", chainName));
        vm.createDir(dirPath, true);
        
        // Save to file
        string memory filePath = string(abi.encodePacked(
            dirPath, 
            "/deployment-", 
            vm.toString(block.timestamp), 
            ".json"
        ));
        vm.writeFile(filePath, json);
        
        // Also save as latest
        string memory latestPath = string(abi.encodePacked(dirPath, "/latest.json"));
        vm.writeFile(latestPath, json);
        
        console.log("");
        console.log("Deployment artifacts saved to:", filePath);
    }

    /**
     * @dev Get human-readable chain name
     */
    function getChainName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 1) return "mainnet";
        if (chainId == 11155111) return "sepolia";
        if (chainId == 31337) return "localhost";
        return "unknown";
    }

    /**
     * @dev Verify contracts on Etherscan (call separately after deployment)
     */
    function verify() external {
        if (!config.verify) {
            console.log("Verification skipped for this network");
            return;
        }
        
        console.log("Verifying contracts on Etherscan...");
        
        // Build verification commands
        console.log("");
        console.log("Run these commands to verify:");
        console.log("");
        console.log("forge verify-contract \\");
        console.log("  --chain-id", config.chainId, "\\");
        console.log("  --num-of-optimizations 200 \\");
        console.log("  --compiler-version v0.8.20 \\");
        console.log(" ", address(doctorNFT), "\\");
        console.log("  src/HealDoctorNFT.sol:HealDoctorNFT");
        console.log("");
        console.log("forge verify-contract \\");
        console.log("  --chain-id", config.chainId, "\\");
        console.log("  --num-of-optimizations 200 \\");
        console.log("  --compiler-version v0.8.20 \\");
        console.log(" ", address(verifier), "\\");
        console.log("  src/HealPrescriptionVerifier.sol:HealPrescriptionVerifier \\");
        console.log("  --constructor-args $(cast abi-encode 'constructor(address)'", address(doctorNFT), ")");
    }
}

/**
 * @title DeployHealLocal
 * @dev Deploys to local Anvil node for testing
 */
contract DeployHealLocal is DeployHeal {
    function run() external returns (HealDoctorNFT, HealPrescriptionVerifier) {
        // Override for local deployment with default Anvil values
        return super.run();
    }
}