// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {AdvancedLendingDeployer} from "../../script/AdvancedLendingDeployment.s.sol";
import {AdvancedLending} from "../../src/AdvancedLending.sol";
import {token} from "../../src/ERC20_token.sol";

contract InteractionsTest is Test, AdvancedLendingDeployer {
    AdvancedLending public advancedLending;
    token public myToken;
    HelperConfig public helperConfig;
    address public contractOwner;

    function setUp() external {
        AdvancedLendingDeployer deployer = new AdvancedLendingDeployer();
        (advancedLending, myToken) = deployer.run();
        contractOwner = advancedLending.getOwnerAddress();
    }

    function test_contractAndTokenDeployment() public {
        assertEq(myToken.balanceOf(contractOwner), 100000e18);
    }

    function test_tokenDeploymentMatchesTokenContract() public {
        address tokenContract = advancedLending.getTokenAddress();
        address tokenDeployed = address(myToken);
        assertEq(tokenContract, tokenDeployed);
    }
}
