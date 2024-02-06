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
    address USER1 = address(1);
    address USER2 = address(2);
    uint256 ethDecimals = 10 ** 18;
    uint256 MAX_TOKEN_SUPPLY = 100000e18;
    uint256 MOCK_ETH_PRICE = 2000;

    function setUp() external {
        testAdvancedLendingDeployer deployer = new testAdvancedLendingDeployer();
        contractOwner = address(deployer);
        vm.deal(USER1, STARTING_USER_BALANCE);
        vm.deal(USER2, STARTING_USER_BALANCE);
        vm.deal(contractOwner, STARTING_USER_BALANCE);
        (advancedLending, myToken) = deployer.run();
    }

    /////////////// Testing receive() ///////////////
    function testFuzz_contractReceivesETH(uint256 amount) public {
        vm.assume(amount < 10);
        vm.prank(USER1);
        (bool success,) = address(advancedLending).call{value: amount * ethDecimals}("");
        require(success, "transfer failed");
        assertEq(address(advancedLending).balance, amount * ethDecimals);
    }

    function testFuzz_collateralDepositBalanceIncreasesByEthAmount(uint256 amount) public {
        vm.assume(amount < 10 ether);
        vm.startPrank(contractOwner);
        (bool success,) = address(advancedLending).call{value: amount}("");
        require(success, "transfer failed");
        assertEq(advancedLending.getCollateralDepositBalance(contractOwner), amount);
    }

    /////////////// Testing depositToken(uint256 amount) ///////////////
    function test_revertWhen_depositAmountIsZero() public {
        vm.startPrank(contractOwner);
        vm.expectRevert(AdvancedLending.amountCannotBeZero.selector);
        advancedLending.depositToken(0);
        vm.stopPrank();
    }

    function testFuzz_lenderBalanceIncreasesByDepositAmount(uint256 amount) public {
        vm.assume(amount != 0 && amount < 10);
        vm.startPrank(contractOwner);
        myToken.approve(address(advancedLending), amount * ethDecimals);
        advancedLending.depositToken(amount * ethDecimals);
        assertEq(advancedLending.getLenderBalance(contractOwner), amount * ethDecimals);
    }

    function testFuzz_contractTokenBalanceIncreasesByDepositAmount(uint256 amount) public {
        vm.assume(amount != 0 && amount < 100000);
        vm.startPrank(contractOwner);
        myToken.approve(address(advancedLending), amount * ethDecimals);
        advancedLending.depositToken(amount * ethDecimals);
        assertEq(myToken.balanceOf(address(advancedLending)), amount * ethDecimals);
        vm.stopPrank();
    }

    /////////////// Testing withdrawToken(uint256 amount) ///////////////
    function test_revertWhen_withdrawAmountIsZero() public {
        vm.startPrank(contractOwner);
        myToken.approve(address(advancedLending), 10e18);
        advancedLending.depositToken(10e18);
        vm.expectRevert(AdvancedLending.amountCannotBeZero.selector);
        advancedLending.withdrawToken(0);
        vm.stopPrank();
    }

    function test_revertWhen_withdrawlAmountExceedsContractBalance() public {
        vm.startPrank(contractOwner);
        myToken.approve(address(advancedLending), 5e18);
        advancedLending.depositToken(5e18);
        vm.expectRevert(AdvancedLending.notEnoughTokensInContractForWithdrawl.selector);
        advancedLending.withdrawToken(6e18);
        vm.stopPrank();
    }

    function test_revertWhen_withdrawlAmountIsGreaterThanDepositAmount() public {
        vm.startPrank(contractOwner);
        myToken.transfer(USER1, 10e18);
        myToken.approve(address(advancedLending), 10e18);
        advancedLending.depositToken(10e18);
        vm.stopPrank();
        vm.startPrank(USER1);
        myToken.approve(address(advancedLending), 1e18);
        advancedLending.depositToken(1e18);
        vm.expectRevert(AdvancedLending.userHasNotDepositedEnoughTokensToMatchThisWithdrawlRequest.selector);
        advancedLending.withdrawToken(10e18);
        vm.stopPrank();
    }

    function testFuzz_lenderBalanceUpdatesWithWithdrawAmount(uint256 amount) public {
        vm.assume(amount != 0 && amount < 100000);
        vm.startPrank(contractOwner);
        myToken.approve(address(advancedLending), amount * ethDecimals);
        advancedLending.depositToken(amount * ethDecimals);
        advancedLending.withdrawToken(amount * ethDecimals);
        assertEq(advancedLending.getLenderBalance(contractOwner), 0);
        vm.stopPrank();
    }

    function testFuzz_contractTokenBalanceDecreasesByWithdrawlAmount(uint256 amount) public {
        vm.assume(amount != 0 && amount < 100000);
        vm.startPrank(contractOwner);
        myToken.approve(address(advancedLending), amount * ethDecimals);
        advancedLending.depositToken(amount * ethDecimals);
        advancedLending.withdrawToken(amount * ethDecimals);
        assertEq(myToken.balanceOf(contractOwner), 100000 * ethDecimals);
        vm.stopPrank();
    }

    /////////////// Testing borrowTokenWithCollateral(uint256 tokenAmount) ///////////////
    function test_revertWhen_borrowAmountIsZero() public {
        vm.startPrank(contractOwner);
        vm.expectRevert(AdvancedLending.amountCannotBeZero.selector);
        advancedLending.borrowTokenWithCollateral{value: 1 ether}(0);
        vm.stopPrank();
    }

    function test_revertWhen_borrowingTokensCausesLoanToBeBelowTheRequiredCollateralRatio(
        uint256 ethAmount,
        uint256 tokenAmount
    ) public {
        vm.assume(ethAmount > 0 && tokenAmount > 0);
        vm.assume(ethAmount < STARTING_USER_BALANCE && tokenAmount < MAX_TOKEN_SUPPLY);
        vm.assume(ethAmount * MOCK_ETH_PRICE * 10 < tokenAmount * 15);
        vm.startPrank(contractOwner);
        myToken.approve(address(advancedLending), MAX_TOKEN_SUPPLY);
        advancedLending.depositToken(MAX_TOKEN_SUPPLY);
        vm.stopPrank();
        vm.startPrank(USER1);
        vm.expectRevert(AdvancedLending.borrowAmountWillCauseLoanToBeBelowTheRequiredCollateralRatio.selector);
        advancedLending.borrowTokenWithCollateral{value: ethAmount}(tokenAmount);
        vm.stopPrank();
    }

    function testFuzz_collateralDepositBalanceIncreasesWhenEthIsDepositedToBorrow(uint256 ethAmount) public {
        vm.assume(ethAmount > 0.0075e18 && ethAmount < STARTING_USER_BALANCE);
        vm.startPrank(contractOwner);
        myToken.approve(address(advancedLending), 10e18);
        advancedLending.depositToken(10e18);
        vm.stopPrank();
        vm.startPrank(USER1);
        advancedLending.borrowTokenWithCollateral{value: ethAmount}(10e18);
        assertEq(advancedLending.getCollateralDepositBalance(USER1), ethAmount);
        vm.stopPrank();
    }

    function testFuzz_borrowBalanceIncreasesByBorrowedAmount(uint256 tokenAmount) public {
        vm.assume(tokenAmount > 0 && tokenAmount < 13333e18);
        vm.startPrank(contractOwner);
        myToken.approve(address(advancedLending), MAX_TOKEN_SUPPLY);
        advancedLending.depositToken(MAX_TOKEN_SUPPLY);
        vm.stopPrank();
        vm.startPrank(USER1);
        advancedLending.borrowTokenWithCollateral{value: 10e18}(tokenAmount);
        vm.stopPrank();
        assertEq(advancedLending.getBorrowerBalance(USER1), tokenAmount);
    }

    function testFuzz_borrowedTokensAreSentToBorrowerAddress(uint256 tokenAmount) public {
        vm.assume(tokenAmount > 0 && tokenAmount < 13333e18);
        vm.startPrank(contractOwner);
        myToken.approve(address(advancedLending), MAX_TOKEN_SUPPLY);
        advancedLending.depositToken(MAX_TOKEN_SUPPLY);
        vm.stopPrank();
        vm.startPrank(USER1);
        advancedLending.borrowTokenWithCollateral{value: STARTING_USER_BALANCE}(tokenAmount);
        vm.stopPrank();
        assertEq(myToken.balanceOf(USER1), tokenAmount);
    }

    /////////////// Testing repaytoken(uint256 tokenAmount) ///////////////
    function test_revertWhen_repaymentAmountIsZero() public {
        vm.startPrank(contractOwner);
        myToken.approve(address(advancedLending), MAX_TOKEN_SUPPLY);
        advancedLending.depositToken(MAX_TOKEN_SUPPLY);
        advancedLending.borrowTokenWithCollateral{value: 5 ether}(100e18);
        vm.expectRevert(AdvancedLending.amountCannotBeZero.selector);
        advancedLending.repayToken(0);
        vm.stopPrank();
    }

    function test_revertWhenRepaymentAmountIsGreaterThanBorrowAmount() public {
        vm.startPrank(contractOwner);
        myToken.transfer(USER1, 100e18);
        myToken.approve(address(advancedLending), MAX_TOKEN_SUPPLY - 100e18);
        advancedLending.depositToken(MAX_TOKEN_SUPPLY - 100e18);
        vm.stopPrank();
        vm.startPrank(USER1);
        advancedLending.borrowTokenWithCollateral{value: 5 ether}(10e18);
        myToken.approve(address(advancedLending), 11e18);
        vm.expectRevert(AdvancedLending.repaymentAmountIsGreaterThanTheAmountOfTokensBorrowed.selector);
        advancedLending.repayToken(11e18);
        vm.stopPrank();
    }

    function test_borrowerBalanceUpdatesWithRepayment() public {
        vm.startPrank(contractOwner);
        myToken.approve(address(advancedLending), MAX_TOKEN_SUPPLY);
        advancedLending.depositToken(MAX_TOKEN_SUPPLY);
        advancedLending.borrowTokenWithCollateral{value: 5 ether}(100e18);
        myToken.approve(address(advancedLending), MAX_TOKEN_SUPPLY);
        advancedLending.repayToken(95e18);
        vm.stopPrank();
        assertEq(advancedLending.getBorrowerBalance(contractOwner), 5e18);
    }

    function testFuzz_repaymentTokensAreTransferredToContract(uint256 tokenAmount) public {
        vm.assume(tokenAmount > 0 && tokenAmount < 12000e18);
        vm.startPrank(contractOwner);
        myToken.approve(address(advancedLending), MAX_TOKEN_SUPPLY);
        advancedLending.depositToken(MAX_TOKEN_SUPPLY);
        advancedLending.borrowTokenWithCollateral{value: 9 ether}(tokenAmount);
        myToken.approve(address(advancedLending), tokenAmount);
        advancedLending.repayToken(tokenAmount);
        vm.stopPrank();
        assertEq(myToken.balanceOf(address(advancedLending)), MAX_TOKEN_SUPPLY);
    }

    /////////////// Testing withdrawCollateral(uint256 collateralAmount) ///////////////
    function test_revertWhen_collateralAmountToWithdrawIsZero() public {
        vm.startPrank(contractOwner);
        (bool success,) = address(advancedLending).call{value: 1 ether}("");
        require(success, "transfer failed");
        vm.expectRevert(AdvancedLending.amountCannotBeZero.selector);
        advancedLending.withdrawCollateral(0);
        vm.stopPrank();
    }

    function testFuzz_revertWhen_withdrawCollateralIsCalledWithAnOpenLoan(uint256 collateralAmount) public {
        vm.assume(collateralAmount > 0 && collateralAmount > 0.00075e18 && collateralAmount < STARTING_USER_BALANCE);
        vm.startPrank(contractOwner);
        myToken.approve(address(advancedLending), MAX_TOKEN_SUPPLY);
        advancedLending.depositToken(MAX_TOKEN_SUPPLY);
        advancedLending.borrowTokenWithCollateral{value: collateralAmount}(1e18);
        vm.expectRevert(AdvancedLending.cannotWithdrawCollateralWithAnOpenLoan.selector);
        advancedLending.withdrawCollateral(collateralAmount);
        vm.stopPrank();
    }
}
