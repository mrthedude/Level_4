// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    function getPriceFeedAddress() public view returns (address priceFeed) {
        if (block.chainid == 534351) {
            // Chainlink ETH/USD price feed
            return 0x6bF14CB0A831078629D993FDeBcB182b21A8774C;
        }
    }
}
