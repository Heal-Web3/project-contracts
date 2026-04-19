// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/**
 * @title HelperConfig
 * @dev Network configuration utility for deployment scripts
 * @notice Provides network-specific configurations for different environments
 */
contract HelperConfig is Script {
    // Configuration structure for each network
    struct NetworkConfig {
        address regulator;          // Regulator wallet address
        uint256 deployerKey;        // Private key for deployment
        string rpcUrl;              // RPC URL for the network
        uint256 chainId;            // Chain ID
        bool verify;                // Whether to verify on Etherscan
    }

    // Active configuration
    NetworkConfig public activeNetworkConfig;

    // Default values for local testing
    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public constant DEFAULT_ANVIL_REGULATOR = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    // Network chain IDs
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    constructor() {
        // Detect current network and set configuration
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaConfig();
        } else if (block.chainid == MAINNET_CHAIN_ID) {
            activeNetworkConfig = getMainnetConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    /**
     * @dev Sepolia testnet configuration
     */
    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            regulator: vm.envAddress("REGULATOR_ADDRESS"),
            deployerKey: vm.envUint("PRIVATE_KEY"),
            rpcUrl: vm.envString("SEPOLIA_RPC_URL"),
            chainId: SEPOLIA_CHAIN_ID,
            verify: true
        });
    }

    /**
     * @dev Ethereum mainnet configuration
     */
    function getMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            regulator: vm.envAddress("REGULATOR_ADDRESS"),
            deployerKey: vm.envUint("PRIVATE_KEY"),
            rpcUrl: vm.envString("MAINNET_RPC_URL"),
            chainId: MAINNET_CHAIN_ID,
            verify: true
        });
    }

    /**
     * @dev Local Anvil configuration for testing
     */
    function getAnvilConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            regulator: DEFAULT_ANVIL_REGULATOR,
            deployerKey: DEFAULT_ANVIL_KEY,
            rpcUrl: "http://localhost:8545",
            chainId: LOCAL_CHAIN_ID,
            verify: false
        });
    }

    /**
     * @dev Get configuration for a specific chain ID
     * @param chainId Target chain ID
     */
    function getConfigByChainId(uint256 chainId) public view returns (NetworkConfig memory) {
        if (chainId == SEPOLIA_CHAIN_ID) {
            return getSepoliaConfig();
        } else if (chainId == MAINNET_CHAIN_ID) {
            return getMainnetConfig();
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getAnvilConfig();
        } else {
            revert("HelperConfig: Unsupported chain ID");
        }
    }

    /**
     * @dev Log current configuration (for debugging)
     */
    function logConfig() public view {
        console.log("=== Network Configuration ===");
        console.log("Chain ID:", activeNetworkConfig.chainId);
        console.log("Regulator:", activeNetworkConfig.regulator);
        console.log("RPC URL:", activeNetworkConfig.rpcUrl);
        console.log("Verify on Etherscan:", activeNetworkConfig.verify);
        console.log("=============================");
    }
}