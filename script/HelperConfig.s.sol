// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MockV3Aggregator} from "../test/MockV3Aggregator.t.sol";
import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8; // 8;
    int256 public constant INITIAL_PRICE = 2000e8; // 2000e8;

    struct NetworkConfig {
        address priceFeed;
    }

    event HelperConfig__CreatedMockPriceFeed(address priceFeed);

    constructor() {
        if (block.chainid == 534351) {
            activeNetworkConfig = getScrollSepoliaConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getScrollSepoliaConfig() public pure returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            priceFeed: 0x6bF14CB0A831078629D993FDeBcB182b21A8774C // ETH/USD price feed
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
        vm.stopBroadcast();
        emit HelperConfig__CreatedMockPriceFeed(address(mockPriceFeed));

        anvilNetworkConfig = NetworkConfig({priceFeed: address(mockPriceFeed)});
    }
}
