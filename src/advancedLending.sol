// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {token} from "./ERC20_token.sol";

/**
 * @title advancedLending
 * @notice This contract allows users to deposit an ERC20 token, borrow against the deposited tokens with ETH as collateral, withdraw deposited tokens or ETH,
 * and liquidate users whos LTV falls below the set COLLATERAL_RATIO
 * @dev This contract integrates a Chainlink price feed for ETH to maintain LTV's, this contract does not incorporate interest rates on lending or borrowing
 */
contract advancedLending {
    error amountCannotBeZero();
    error notEnoughTokensInContractForWithdrawl();
    error userHasNotDepositedEnoughTokensToMatchThisWithdrawlRequest();
    error contractCallNotRecognized();
    error repaymentAmountIsGreaterThanTheAmountOfTokensBorrowed();

    using SafeERC20 for IERC20;

    /// @notice ERC20 token that the contract uses for borrowing and lending
    IERC20 public immutable i_token;

    /// @notice Represents the minimum LTV ratio a borrower can have before becoming eligible for liquidation
    uint256 public constant COLLATERAL_RATIO = 150; // 150% LTV

    /// @dev mapping tracking lenders' balances
    mapping(address lender => uint256 amount) private lenderBalance;

    /// @dev mapping tracking borrowers' balances
    mapping(address borrower => uint256 amount) private borrowerBalance;

    event lendingPoolIncreased(
        address indexed user, uint256 indexed amountDeposited, uint256 indexed totalContractTokenBalance
    );
    event lenderWithdrewTokens(
        address indexed user, uint256 indexed amountWithdrawn, uint256 indexed totalContractTokenBalance
    );

    event ethDepositedIntoContract(
        address indexed user, uint256 indexed amountDeposited, uint256 indexed totalContractEthBalance
    );

    event borrowerReducedDebt(address indexed user, uint256 indexed amountRepaid, uint256 indexed remainingDebtOfUser);

    modifier cannotBeZero(uint256 amount) {
        if (amount == 0) {
            revert amountCannotBeZero();
        }
        _;
    }

    /**
     * @notice This constructor function sets the token contract on deployment
     * @param tokenContract The ERC20 token contract that advancedLending can use for lending and borrowing
     */
    constructor(address tokenContract) {
        i_token = IERC20(tokenContract);
    }

    /// @notice Allows contract to receive Ether without calling a function and emits an event
    receive() external payable {
        emit ethDepositedIntoContract(msg.sender, msg.value, address(this).balance);
    }

    /// @notice Throws an error when a function call is made to the contract that does not match any function signatures
    fallback() external {
        revert contractCallNotRecognized();
    }

    /**
     * @notice A function that allows users to deposit ERC20 tokens into the contract, which can be borrowed against ETH collateral up to a set LTV
     * @param amount The amount of tokens to deposit
     */
    function depositToken(uint256 amount) external cannotBeZero(amount) {
        i_token.safeTransferFrom(msg.sender, address(this), amount);
        lenderBalance[msg.sender] += amount;
        emit lendingPoolIncreased(msg.sender, amount, i_token.balanceOf(address(this)));
    }

    /**
     * @notice A function that allows users to withdraw tokens that they have deposited in the contract, if the tokens are available for withdrawl (not borrowed)
     * @param amount The amount of tokens to withdraw
     */
    function withdrawToken(uint256 amount) external cannotBeZero(amount) {
        if (i_token.balanceOf(address(this)) < amount) {
            revert notEnoughTokensInContractForWithdrawl();
        }
        if (lenderBalance[msg.sender] < amount) {
            revert userHasNotDepositedEnoughTokensToMatchThisWithdrawlRequest();
        }
        i_token.safeTransfer(msg.sender, amount);
        lenderBalance[msg.sender] -= amount;
        emit lenderWithdrewTokens(msg.sender, amount, i_token.balanceOf(address(this)));
    }

    /**
     * @notice A function that allows users to borrow deposited tokens with ETH collateral that they deposit in the contract, limited by the amount of tokens in the
     * contract and the LTV of the user's deposited ETH collateral and the token amount they specify to borrow
     * @param tokenAmount The amount of tokens to be borrowed
     */
    function borrowTokenWithCollateral(uint256 tokenAmount) external payable {}

    /**
     * @notice A function that allows users to repay the tokens they have borrowed using the borrowTokenWithCollateral function
     * @notice A user's collateral becomes available for withdrawl when their loan is completely paid off
     * @param tokenAmount The amount of tokens used to repay an outstanding loan
     */
    function repayToken(uint256 tokenAmount) external cannotBeZero(tokenAmount) {
        if (borrowerBalance[msg.sender] < tokenAmount) {
            revert repaymentAmountIsGreaterThanTheAmountOfTokensBorrowed();
        }
        i_token.safeTransferFrom(msg.sender, address(this), tokenAmount);
        borrowerBalance[msg.sender] -= tokenAmount;
        emit borrowerReducedDebt(msg.sender, tokenAmount, borrowerBalance[msg.sender]);
    }

    /**
     * @notice A function that allows users to withdraw their ETH collateral if they don't have an outstanding loan and if the withdrawl does not cause a user's
     * LTV to fall below the required COLLATERAL_RATIO
     * @param collateralAmount The amount of ETH collateral to be withdrawn
     */
    function withdrawCollateral(uint256 collateralAmount) external {}

    /**
     * @notice A funciton that allows users to liquidate other users' loans whos LTVs have fallen below the required COLLATERAL_RATIO
     * @notice This function ensures that the contract stays solvent and lenders do not incure losses from borrowers with near-undercollateralized loans
     * @param borrower The address of the user with an outstanding loan that is eligible to be liquidated
     * @param loanAmount The amount of tokens borrowed in the now unhealthy loan
     */
    function liquidate(address borrower, uint256 loanAmount) external {}
}
