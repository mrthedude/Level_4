// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {token} from "../src/ERC20_token.sol";
import {AdvancedLending} from "../src/AdvancedLending.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract AdvancedLendingDeployer is Script, HelperConfig {
    function run() public returns (AdvancedLending, token) {
        HelperConfig helperConfig = new HelperConfig();
        address owner = helperConfig.getOwnerAddress();
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();
        vm.startBroadcast();
        token myToken = new token(owner);
        AdvancedLending advancedLending = new AdvancedLending(myToken, ethUsdPriceFeed, owner);
        vm.stopBroadcast();
        return (advancedLending, myToken);
    }
}
