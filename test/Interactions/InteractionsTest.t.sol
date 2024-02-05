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

    function setUp() external {
        testAdvancedLendingDeployer deployer = new testAdvancedLendingDeployer();
        contractOwner = address(deployer);
        (advancedLending, myToken) = deployer.run();
    }

    function test_contractAndTokenDeployment() public {
        assertEq(myToken.balanceOf(contractOwner), 100000e18);
    }

    function test_tokenDeploymentMatchesTokenContract() public {
        address tokenContract = advancedLending.getTokenAddress();
        address tokenDeployed = address(myToken);
        console.log(tokenContract, tokenDeployed);
        assertEq(tokenContract, tokenDeployed);
    }
}
