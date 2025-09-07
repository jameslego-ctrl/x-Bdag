



# BdagTokenEngine

## Overview

**BdagTokenEngine** is a Solidity smart contract designed to manage minting and burning of BDAG tokens while maintaining a 1:1 peg with the BlockDag USD value. It uses native BDAG tokens as collateral to back newly minted BDAG tokens. The contract is intended to be owned and controlled by a LendingPool contract with exclusive rights to mint and burn BDAG.

This contract inherits from OpenZeppelin's **ReentrancyGuard** for protection against reentrancy attacks and the **ERC20** standard for token functionality.

---

## Features

- **Collateral Deposit & Minting**  
  Users deposit native BDAG tokens as collateral and mint new BDAG tokens proportionally.

- **Collateral Redemption**  
  Users can redeem their collateral by burning BDAG tokens and withdrawing the locked collateral.

- **Health Factor Enforcement**  
  Ensures users maintain a minimum collateralization ratio (health factor) to avoid under-collateralization and potential liquidation.

- **Reentrancy Protection**  
  Protects critical functions like minting, burning, and redeeming collateral from reentrancy attacks.

---

## Contract Details

### Constants

- `PRECISION`: Decimal precision for calculations (1e18).
- `LIQUIDATION_THRESHOLD`: 50% threshold for liquidation.
- `LIQUIDATION_PRECISION`: Precision factor for liquidation (100).
- `MIN_HEALTH_FACTOR`: Minimum required health factor (1).
- `BDAG_PRICE`: Fixed price of $1 per BDAG token (for peg enforcement).

### Key Mappings

- `s_collateralBalances`: Tracks user's deposited collateral balances.
- `s_bdagMinted`: Tracks the amount of BDAG minted per user.
- `s_users`: List of users who have interacted with the protocol.

---

## Important Functions

### `depositCollateralAndMintBdag`


- Allows users to deposit collateral and mint BDAG tokens in one call.
- Requires the sent ETH amount (`msg.value`) to match or exceed collateral * `PRECISION`.
- Updates user's collateral balance and mints BDAG tokens accordingly.
  
### `redeemCollateral`


- Allows users to redeem their collateral by withdrawing Ether.
- Checks that the user has enough collateral deposited.
- Sends Ether back to the user and updates collateral balances.
- Checks if user's health factor remains valid after redemption.

### `mintBdag`


- Users mint BDAG tokens against their deposited collateral.
- Enforces that user has sufficient collateral to mint requested amount.
- Mints tokens and updates the user’s collateral balance.

### `burnBdag`


- Users burn BDAG tokens to reduce their debt.
- Updates collateral balance accordingly.
- Checks health factor after burning tokens.

### `revertIfHealthFactorIsBroken`


- Checks if the user's health factor is above the minimum threshold.
- Reverts if user would be undercollateralized.

### `getUserInfo`


- Returns collateral value in USD, minted BDAG amount, and current health factor for a given user.

---

## Events

- `collateralDeposited(address user, uint256 amount)`: Emitted when collateral is deposited.
- `collateralRedeemed(address user, uint256 amount)`: Emitted when collateral is redeemed.

---

## Usage Notes

- Collateral amounts and minted BDAG are calculated using fixed-point arithmetic with 18 decimals (`PRECISION`).
- The health factor enforces a minimum collateralization ratio to keep the system solvent.
- The contract follows security best practices including reentrancy guards on critical functions.
- Designed to be owned and controlled by a LendingPool contract with exclusive rights to mint and burn.

---

## Requirements

- Solidity version 0.8.20 or above.
- OpenZeppelin Contracts for `ReentrancyGuard` and `ERC20`.

---

## License

MIT License

---

## Author

James Lego

---

For more details, review the contract source code and accompanying documentation.


