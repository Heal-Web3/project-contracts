// // SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address regulator;
        uint256 deployerKey;
        string rpcUrl;
        uint256 chainId;
        bool verify;
    }

    NetworkConfig public activeNetworkConfig;

    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public constant DEFAULT_ANVIL_REGULATOR = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    constructor() {
        activeNetworkConfig = getNetworkConfigByChainId(block.chainid);
    }

    function getNetworkConfigByChainId(uint256 chainId) public view returns (NetworkConfig memory) {
        if (chainId == SEPOLIA_CHAIN_ID) {
            return getSepoliaConfig();
        } else if (chainId == MAINNET_CHAIN_ID) {
            return getMainnetConfig();
        } else {
            return getAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            regulator: vm.envAddress("REGULATOR_ADDRESS"),
            deployerKey: vm.envUint("PRIVATE_KEY"),
            rpcUrl: vm.envString("SEPOLIA_RPC_URL"),
            chainId: SEPOLIA_CHAIN_ID,
            verify: true
        });
    }

    function getMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            regulator: vm.envAddress("REGULATOR_ADDRESS"),
            deployerKey: vm.envUint("PRIVATE_KEY"),
            rpcUrl: vm.envString("MAINNET_RPC_URL"),
            chainId: MAINNET_CHAIN_ID,
            verify: true
        });
    }

    function getActiveNetworkConfig() external view returns (NetworkConfig memory) {
    return activeNetworkConfig;
}

    function getAnvilConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            regulator: DEFAULT_ANVIL_REGULATOR,
            deployerKey: DEFAULT_ANVIL_KEY,
            rpcUrl: "http://localhost:8545",
            chainId: LOCAL_CHAIN_ID,
            verify: false
        });
    }
}