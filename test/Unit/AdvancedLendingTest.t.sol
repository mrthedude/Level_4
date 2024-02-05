// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {testAdvancedLendingDeployer} from "../../script/AdvancedLendingDeployment.s.sol";
import {AdvancedLending} from "../../src/AdvancedLending.sol";
import {token} from "../../src/ERC20_token.sol";

contract InteractionsTest is Test, testAdvancedLendingDeployer {
    AdvancedLending public advancedLending;
    token public myToken;
    HelperConfig public helperConfig;
    address public contractOwner;
    uint256 public STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        testAdvancedLendingDeployer deployer = new testAdvancedLendingDeployer();
        contractOwner = address(deployer);
        (advancedLending, myToken) = deployer.run();
    }
}
