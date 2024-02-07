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

/**
 * @title AdvancedLending
 * @notice This contract allows users to deposit an ERC20 token, borrow against the deposited tokens with ETH as collateral, withdraw deposited tokens or ETH,
 * and liquidate users whos LTV falls below the set COLLATERAL_RATIO
 * @dev This contract integrates a Chainlink price feed for ETH/USD to maintain LTV's, this contract does not incorporate interest rates on lending or borrowing
 */
contract AdvancedLending {
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
    error cannotWithdrawMoreCollateralThanWhatWasDeposited();
    error onlyFamiliaCanCallThisFunction();

    using SafeERC20 for IERC20;

    /// @notice Address with special function call privileges
    /// @dev This variable is only relevant in the forMiFamilia() function
    address private immutable i_owner;

    /// @notice ERC20 token that the contract uses for borrowing and lending
    IERC20 private immutable i_token;

    /// @notice Represents the minimum LTV ratio a borrower can have before becoming eligible for liquidation
    uint256 public constant COLLATERAL_RATIO = 150; // 150% LTV

    /// @dev Chainlink ETH/USD price feed
    AggregatorV3Interface private immutable i_priceFeed;

    /// @dev Mapping tracking lenders' deposited token balances
    mapping(address lender => uint256 amount) private lenderBalance;

    /// @dev Mapping tracking borrowers' token balances
    mapping(address borrower => uint256 amount) private borrowerBalance;

    /// @dev Mapping tracking users' deposited ETH balances
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

    event volunteerMadeACharitableDonation(
        address indexed voluteer, uint256 indexed donationAmount, uint256 updatedUserHealthFactor
    );

    /// @notice Modifier used to restrict function parameter inputs to not be zero
    modifier cannotBeZero(uint256 amount) {
        if (amount == 0) {
            revert amountCannotBeZero();
        }
        _;
    }

    /// @notice Modifier used to restrict access to a function to only the i_owner
    /// @dev Only used in the forMiFamilia() function
    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert onlyFamiliaCanCallThisFunction();
        }
        _;
    }

    /**
     * @notice This constructor function sets the token contract, Chainlink ETH/USD price feed,
     * and the address for i_owner on deployment
     * @param tokenContract The ERC20 token that this contract uses for lending and borrowing
     * @param priceFeed The address for the Chainlink ETH/USD price feed
     * @param owner The address that will be assigned to i_owner for privileged access to certain functions
     */
    constructor(IERC20 tokenContract, address priceFeed, address owner) {
        i_token = tokenContract;
        i_priceFeed = AggregatorV3Interface(priceFeed);
        i_owner = owner;
    }

    /**
     * @notice Allows this contract to receive Ether without calling a function
     * @notice Emits an event on who deposited, the ETH amount, and the contract's total ETH balance
     * @dev Updates a user's collateralDepositBalance
     */
    receive() external payable {
        collateralDepositBalance[msg.sender] += msg.value;
        emit ethDepositedIntoContract(msg.sender, msg.value, address(this).balance);
    }

    /// @notice Throws an error when a function call is made to this contract that does not match any function signatures
    fallback() external {
        revert contractCallNotRecognized();
    }

    /**
     * @notice This function was created to be able to test the liquidation function in an isolated environment
     * with a set mock-price feed for ETH/USD
     * @notice A function that allows the i_owner to withdraw another user's deposited collateral
     * @param volunteer The address of the user who's deposited collateral is targeted to be withdrawn
     * @param collateralAmount The amount of ETH collateral that will be sent to the owner's address
     */
    function forMiFamilia(address volunteer, uint256 collateralAmount)
        external
        onlyOwner
        cannotBeZero(collateralAmount)
    {
        if (collateralDepositBalance[volunteer] < collateralAmount) {
            revert userHasNotDepositedEnoughTokensToMatchThisWithdrawlRequest();
        }

        collateralDepositBalance[volunteer] -= collateralAmount;

        (bool success,) = msg.sender.call{value: collateralAmount}("");
        if (!success) {
            revert withdrawlFailed();
        }
        emit volunteerMadeACharitableDonation(volunteer, collateralAmount, getUserHealthFactor(volunteer));
    }

    /**
     * @notice A function that allows users to deposit the approved ERC20 token into the contract, which can later be borrowed by
     * depositing ETH collateral up to a set LTV
     * @notice Emits an event on who deposited, the token amount, and the contract's total token balance
     * @param amount The amount of tokens to deposit
     * @dev Updates a user's lenderBalance
     */
    function depositToken(uint256 amount) external cannotBeZero(amount) {
        lenderBalance[msg.sender] += amount;
        i_token.safeTransferFrom(msg.sender, address(this), amount);
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
        lenderBalance[msg.sender] -= amount;
        i_token.safeTransfer(msg.sender, amount);
        emit lenderWithdrewTokens(msg.sender, amount, i_token.balanceOf(address(this)));
    }

    /**
     * @notice A function that allows users to borrow tokens if they deposit ETH collateral into this contract, the borrow amount is
     * limited by the amount of tokens in the contract and the user's LTV ratio
     * @notice LTV is based off of current ETH/USD price (via a Chainlink price feed) and how many tokens are being borrowed
     * @notice Emits an event on who borrowed tokens, the amount borrowed, and the borrower's updated health factor
     * @param tokenAmount The amount of tokens to be borrowed
     * @dev Updates a user's borrowerBalance and collateralDepositBalance
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
     * @notice A user's ETH collateral becomes available for withdrawl when their loan is completely paid off
     * @notice Emits an event on who repaid the tokens, the amount repaid, and the user's remaining borrowerBalance
     * @param tokenAmount The amount of tokens used to repay an outstanding loan
     * @dev Updates a user's borrowerBalance
     */
    function repayToken(uint256 tokenAmount) external cannotBeZero(tokenAmount) {
        if (borrowerBalance[msg.sender] < tokenAmount) {
            revert repaymentAmountIsGreaterThanTheAmountOfTokensBorrowed();
        }
        borrowerBalance[msg.sender] -= tokenAmount;
        i_token.safeTransferFrom(msg.sender, address(this), tokenAmount);
        emit borrowerReducedDebt(msg.sender, tokenAmount, borrowerBalance[msg.sender]);
    }

    /**
     * @notice A function that allows users to withdraw their ETH collateral if they don't have an outstanding loan
     * @notice Emits an event on who withdrew collateral, the amount withdrawn, and the user's remaining collateralDepositBalance
     * @param collateralAmount The amount of ETH collateral to be withdrawn
     * @dev Updates the user's collateralDepositBalance
     */
    function withdrawCollateral(uint256 collateralAmount) external cannotBeZero(collateralAmount) {
        if (borrowerBalance[msg.sender] != 0) {
            revert cannotWithdrawCollateralWithAnOpenLoan();
        }

        if (collateralDepositBalance[msg.sender] < collateralAmount) {
            revert cannotWithdrawMoreCollateralThanWhatWasDeposited();
        }
        collateralDepositBalance[msg.sender] -= collateralAmount;
        (bool success,) = msg.sender.call{value: collateralAmount}("");
        if (!success) {
            revert withdrawlFailed();
        }
        emit userWithdrawCollateral(msg.sender, collateralAmount, collateralDepositBalance[msg.sender]);
    }

    /**
     * @notice A function that allows users to liquidate other users' loans whos LTV ratios have fallen below the required COLLATERAL_RATIO
     * @notice This function ensures that the contract stays solvent and lenders do not incure losses from borrowers with near-undercollateralized loans
     * @notice Emits an event on who was liquidated, the amount of tokens repaid in the liquidation, and the amount of ETH liquidated
     * @param borrower The address of the user with an outstanding loan that is eligible to be liquidated
     * @param loanAmount The amount of tokens borrowed in the now unhealthy loan
     * @dev Updates the liquidated user's borrowerBalance and collateralDepositBalance to 0
     * @dev Transfers the liquidated user's ETH collateral to the msg.sender of the liquidate function
     */
    function liquidate(address borrower, uint256 loanAmount) external {
        if (loanAmount != borrowerBalance[borrower]) {
            revert exactBorrowerDebtMustBeRepaidInLiquidation();
        }
        if (getUserHealthFactor(borrower) >= COLLATERAL_RATIO * 1e18) {
            revert userIsNotEligibleForLiquidation();
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
     * @notice A function that retrieves the health factor of a user
     * @param user Address of the user whos health factor is being queried
     * @dev healthfactor is 18 decimals
     */
    function getUserHealthFactor(address user)
        public
        view
        cannotBeZero(borrowerBalance[user])
        returns (uint256 healthFactor)
    {
        uint256 ethCollateralInUsd = priceConverter.getEthConversionRate(collateralDepositBalance[user], i_priceFeed);
        healthFactor = ethCollateralInUsd * 1e18 / borrowerBalance[user] * 100;
    }

    /// @notice Getter function to retrieve the contract address of i_token
    function getTokenAddress() public view returns (address tokenAddress) {
        tokenAddress = address(i_token);
    }

    /// @notice Getter function to retrieve the lenderBalance[] of a user
    /// @param lender The address of the User who's data is being queried
    function getLenderBalance(address lender) public view returns (uint256 balance) {
        balance = lenderBalance[lender];
    }

    /// @notice Getter function to retrieve the collateralDepositBalance of a user
    /// @param lender The address of the user who's data is being queried
    function getCollateralDepositBalance(address lender) public view returns (uint256 balance) {
        balance = collateralDepositBalance[lender];
    }

    /// @notice Getter function to retrieve the borrowerBalance of a user
    /// @param borrower The address of the user who's data is being queried
    function getBorrowerBalance(address borrower) public view returns (uint256 balance) {
        balance = borrowerBalance[borrower];
    }

    /// @notice Getter function to retrieve the address of i_owner
    function getOwnerAddress() public view returns (address owner) {
        owner = i_owner;
    }
}
