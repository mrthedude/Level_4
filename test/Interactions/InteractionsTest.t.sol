// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {testAdvancedLendingDeployer} from "../../script/AdvancedLendingDeployment.s.sol";
import {AdvancedLending} from "../../src/AdvancedLending.sol";

contract InteractionsTest is StdCheats, Test {
    AdvancedLending public advancedLending;
    HelperConfig public helperConfig;

    function setUp() external {}
}
