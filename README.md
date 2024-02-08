## AdvancedLending: LEVEL 4

**This is a lending and borrowing contract with ETH as eligible collateral for ERC20 loans. Liquidation and Chainlink ETH/USD price feed functionality is integrated into this project**

## Contract Descriptions:

- **ERC20_token.sol**: The ERC20 token that is deployed in tandem with the `AdvancedLending.sol` contract. This token is the only ERC20 that is compatible with the contract from lending and borrowing.

- **AdvancedLending.sol**: A lending and borrowing contract with liquidation mechanics, an integrated Chainlink ETH/USD price feed to provide realistic LTV's for users. This contract uses ETH as its only eligible collateral and the ERC20 token in `ERC20_token.sol` as its only eligible lending and borrowing token.

  **priceConverter.sol**: Uses the provided Chainlink ETH/USD price feed to convert any amount of ETH to its current dollar value

- **HelperConfig.s.sol**: Enables for modular deployments in regards to the contract/token owner and the price feed being used, allowing for mock-price feed generation for testing.

- **AdvancedLendingDeployment.s.sol**: Modular deployment contract that deploys `AdvancedLending.sol` and `ERC20_token.sol` with constructor parameters that are programmatically determinded in `HelperConfig.s.sol`, allowing for local testing as well as production deployments.

- **InteractionsTest.t.sol**: Verifies the functionality of the deployment contract `AdvancedLendingDeployment.s.sol`

  **AdvancedLendingTest.t.sol**: Unit tests verifying the functionality of `AdvancedLending.sol` and `ERC20_token.sol`

  **MockV3Aggregator.t.sol**: Simulates the `AggregatorV3Interface` contract to allow for price feed testing in a development environment
