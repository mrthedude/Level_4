// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {token} from "../src/ERC20_token.sol";
import {AdvancedLending} from "../src/AdvancedLending.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract tokenDeployer is Script {
    function run() public returns (token) {
        vm.startBroadcast();
        token myToken = new token();
        vm.stopBroadcast();
        return myToken;
    }
}

// contract testCollateralLendingDeployer is Script, tokenDeployer {
//     function testRun() public returns (AdvancedLending) {
//         token testToken = tokenDeployer.run();
//         vm.startBroadcast();
//         AdvancedLending advancedLending = new AdvancedLending(address(testToken), /**NEED TO INSERT MOCK PRICE FEED */);
//         vm.stopBroadcast();
//         return advancedLending;
//     }
// }

contract AdvancedLendingDeployer is Script {
    function run() public returns (AdvancedLending) {
        address tokenAddress = 0xdd74f39b130298EE194a12bE0eDCE18f1D8Fb36a;
        address ethUsdPriceFeed = 0x6bF14CB0A831078629D993FDeBcB182b21A8774C;
        vm.startBroadcast();
        AdvancedLending advancedLending = new AdvancedLending(tokenAddress, ethUsdPriceFeed);
        vm.stopBroadcast();
        return advancedLending;
    }
}
