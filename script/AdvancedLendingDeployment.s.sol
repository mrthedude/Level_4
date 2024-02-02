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

// contract AdvancedLendingDeployer is Script {
//     function run() public returns (AdvancedLending) {
//         address tokenAddress = /**NEED TO INSERT TOKEN ADDRESS */;
//         vm.startBroadcast();
//         AdvancedLending advancedLending = new AdvancedLending(/**NEED TO INSERT FUNCTION VARIABLE FOR TOKEN ADDRESS */, 0x6bF14CB0A831078629D993FDeBcB182b21A8774C);
//         vm.stopBroadcast();
//         return advancedLending;
//     }
// }
