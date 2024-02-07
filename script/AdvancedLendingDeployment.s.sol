// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {token} from "../src/ERC20_token.sol";
import {AdvancedLending} from "../src/AdvancedLending.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract tokenDeployer is Script {
    function run() public returns (token) {
        vm.startBroadcast();
        token myToken = new token(msg.sender);
        vm.stopBroadcast();
        return myToken;
    }
}

contract testAdvancedLendingDeployer is Script, HelperConfig {
    function run() public returns (AdvancedLending, token) {
        HelperConfig helperConfig = new HelperConfig();
        address owner = helperConfig.getOwnerAddress();
        token myToken = new token(owner);
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();
        vm.startBroadcast();
        AdvancedLending advancedLending = new AdvancedLending(myToken, ethUsdPriceFeed, owner);
        vm.stopBroadcast();
        return (advancedLending, myToken);
    }
}

// contract AdvancedLendingDeployer is Script {
//     function run() public returns (AdvancedLending) {
//         address tokenAddress = 0xdd74f39b130298EE194a12bE0eDCE18f1D8Fb36a;
//         address ethUsdPriceFeed = 0x6bF14CB0A831078629D993FDeBcB182b21A8774C;
//         vm.startBroadcast();
//         AdvancedLending advancedLending = new AdvancedLending(tokenAddress, ethUsdPriceFeed);
//         vm.stopBroadcast();
//         return advancedLending;
//     }
// }
