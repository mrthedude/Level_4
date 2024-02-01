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
import {priceConverter} from "./priceConverter.sol";
import {AggregatorV3Interface} from
    "chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

error amountCannotBeZero();
error notEnoughTokensInContractForWithdrawl();
error userHasNotDepositedEnoughTokensToMatchThisWithdrawlRequest();
error contractCallNotRecognized();
error repaymentAmountIsGreaterThanTheAmountOfTokensBorrowed();
error borrowAmountWillCauseLoanToBeBelowTheRequiredCollateralRatio();
error cannotWithdrawCollateralWithAnOpenLoan();
error withdrawlFailed();
error userIsNotEligibleForLiquidation();
error exactBorrowerDebtMustBeRepaidInLiquidation();

/**
 * @title advancedLending
 * @notice This contract allows users to deposit an ERC20 token, borrow against the deposited tokens with ETH as collateral, withdraw deposited tokens or ETH,
 * and liquidate users whos LTV falls below the set COLLATERAL_RATIO
 * @dev This contract integrates a Chainlink price feed for ETH to maintain LTV's, this contract does not incorporate interest rates on lending or borrowing
 */
contract advancedLending {
    using SafeERC20 for IERC20;

    /// @notice ERC20 token that the contract uses for borrowing and lending
    IERC20 public immutable i_token;

    /// @notice Represents the minimum LTV ratio a borrower can have before becoming eligible for liquidation
    uint256 public constant COLLATERAL_RATIO = 150; // 150% LTV

    /// @dev ETH/USD price feed using Chainlink
    AggregatorV3Interface private immutable i_priceFeed;

    /// @dev mapping tracking lenders' deposited token balances
    mapping(address lender => uint256 amount) private lenderBalance;

    /// @dev mapping tracking borrowers' token balances
    mapping(address borrower => uint256 amount) private borrowerBalance;

    /// @dev mapping for tracking users' deposited ETH balances to update LTV's
    mapping(address collateralDepositor => uint256 collateralAmount) private collateralDepositBalance;

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

    event userBorrowedTokens(address indexed user, uint256 indexed borrowedAmount, uint256 updatedUserHealthFactor);

    event userWithdrawCollateral(
        address indexed user, uint256 collateralAmountWithdrawn, uint256 remainingUserCollateralDeposited
    );

    event userLiquidated(
        address indexed liquidatedUser, uint256 indexed repaidTokenDebt, uint256 indexed ethAmountLiquidated
    );

    modifier cannotBeZero(uint256 amount) {
        if (amount == 0) {
            revert amountCannotBeZero();
        }
        _;
    }

    /**
     * @notice This constructor function sets the token contract and Chainlink price feed on deployment
     * @param tokenContract The ERC20 token contract that advancedLending can use for lending and borrowing
     * @param priceFeed The contract address for the Chainlink ETH/USD price feed
     */
    constructor(address tokenContract, address priceFeed) {
        i_token = IERC20(tokenContract);
        i_priceFeed = AggregatorV3Interface(priceFeed);
    }

    /**
     * @notice Allows contract to receive Ether without calling a function and emits an event on who deposited, the ETH amount, and the contract's total ETH balance
     * @dev Updates a user's collateralDepositBalance
     */
    receive() external payable {
        collateralDepositBalance[msg.sender] += msg.value;
        emit ethDepositedIntoContract(msg.sender, msg.value, address(this).balance);
    }

    /// @notice Throws an error when a function call is made to the contract that does not match any function signatures
    fallback() external {
        revert contractCallNotRecognized();
    }

    /**
     * @notice A function that allows users to deposit the approved ERC20 token into the contract, which can later be borrowed by
     * depositing ETH collateral up to a set LTV
     * @notice Emits an event on who deposited, the token amount, and the contract's total token balance
     * @param amount The amount of tokens to deposit
     * @dev Updates a user's lenderBalance
     */
    function depositToken(uint256 amount) external cannotBeZero(amount) {
        i_token.safeTransferFrom(msg.sender, address(this), amount);
        lenderBalance[msg.sender] += amount;
        emit lendingPoolIncreased(msg.sender, amount, i_token.balanceOf(address(this)));
    }

    /**
     * @notice A function that allows users to withdraw the approved ERC20 token that they have deposited in the contract,
     * but only if there are enough tokens in the contract to meet the withdrawl request
     * @notice Emits an event on who withdrew, the token amount, and the contract's total token balance
     * @param amount The amount of tokens to withdraw
     * @dev Updates a user's lenderBalance
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
     * @notice A function that allows users to borrow deposited tokens with ETH collateral that they deposited in the contract, limited by the amount of tokens in the
     * contract and the user's LTV
     * @notice LTV is based off of current ETH price in USD (via Chainlink oracle) and how many tokens are being borrowed
     * @notice Emits an event on who borrowed tokens, the token amount, and the borrower's updated health factor
     * @param tokenAmount The amount of tokens to be borrowed
     * @dev User's borrowed balance and collateral deposit balance both update upon a successful function call
     * @dev Updates a user's borrowerBalance and their collateralDepositBalance
     */
    function borrowTokenWithCollateral(uint256 tokenAmount) external payable cannotBeZero(tokenAmount) {
        if (
            (priceConverter.getEthConversionRate(collateralDepositBalance[msg.sender] + msg.value, i_priceFeed)) * 1e18
                / (tokenAmount + borrowerBalance[msg.sender]) * 100 < COLLATERAL_RATIO * 1e18
        ) {
            revert borrowAmountWillCauseLoanToBeBelowTheRequiredCollateralRatio();
        }
        collateralDepositBalance[msg.sender] += msg.value;
        borrowerBalance[msg.sender] += tokenAmount;
        i_token.safeTransfer(msg.sender, tokenAmount);
        emit userBorrowedTokens(msg.sender, tokenAmount, getUserHealthFactor(msg.sender));
    }

    /**
     * @notice A function that allows users to repay borrowed tokens
     * @notice A user's collateral becomes available for withdrawl when their loan is completely paid off
     * @notice Emits an event on who repaid the tokens, the amount of tokens repaid, and the user's remaining borrowerBalance
     * @param tokenAmount The amount of tokens used to repay an outstanding loan
     * @dev Updates a user's borrowerBalance
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
     * @notice A function that allows users to withdraw their ETH collateral if they don't have an outstanding loan
     * @notice Emits an event on who withdrew collateral, the amount of collateral withdrawn, and the remaining collateralDepositBalance of the user
     * @param collateralAmount The amount of ETH collateral to be withdrawn
     * @dev Updates the user's collateralDepositBalance by subracting collateralAmount from the initial balance
     */
    function withdrawCollateral(uint256 collateralAmount) external cannotBeZero(collateralAmount) {
        if (borrowerBalance[msg.sender] != 0) {
            revert cannotWithdrawCollateralWithAnOpenLoan();
        }
        (bool success,) = msg.sender.call{value: collateralAmount}("");
        if (!success) {
            revert withdrawlFailed();
        }
        collateralDepositBalance[msg.sender] -= collateralAmount;
        emit userWithdrawCollateral(msg.sender, collateralAmount, collateralDepositBalance[msg.sender]);
    }

    /**
     * @notice A function that allows users to liquidate other users' loans whos LTVs have fallen below the required COLLATERAL_RATIO
     * @notice This function ensures that the contract stays solvent and lenders do not incure losses from borrowers with near-undercollateralized loans
     * @notice Emits an event on who was liquidated, the amount of tokens repaid in the liquidation, and the amount of ETH liquidated
     * @param borrower The address of the user with an outstanding loan that is eligible to be liquidated
     * @param loanAmount The amount of tokens borrowed in the now unhealthy loan
     * @dev Updates the liquidated user's borrowerBalance and collateralDepositBalance to 0
     */
    function liquidate(address borrower, uint256 loanAmount) external {
        if (getUserHealthFactor(borrower) >= COLLATERAL_RATIO * 1e18) {
            revert userIsNotEligibleForLiquidation();
        }
        if (loanAmount != borrowerBalance[borrower]) {
            revert exactBorrowerDebtMustBeRepaidInLiquidation();
        }

        uint256 liquidatedEth = collateralDepositBalance[borrower];

        i_token.safeTransferFrom(msg.sender, address(this), loanAmount);
        (bool success,) = msg.sender.call{value: collateralDepositBalance[borrower]}("");
        if (!success) {
            revert withdrawlFailed();
        }
        borrowerBalance[borrower] = 0;
        collateralDepositBalance[borrower] = 0;
        emit userLiquidated(borrower, loanAmount, liquidatedEth);
    }

    /**
     * @notice A function that allows anyone to retrieve the health factor of a specified address
     * @param user Address of the user whos health factor is being queried
     * @dev healthfactor is 18 decimals
     */
    function getUserHealthFactor(address user)
        public
        view
        cannotBeZero(borrowerBalance[user])
        returns (uint256 healthFactor)
    {
        uint256 ethBorrowedInUsd = priceConverter.getEthConversionRate(collateralDepositBalance[user], i_priceFeed);
        healthFactor = ethBorrowedInUsd * 1e18 / borrowerBalance[user] * 100;
    }
}
