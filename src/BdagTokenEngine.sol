// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title BdagTokenEngine
 * @author James Lego
 * @notice This contract acts as an engine for minting and burning BDAG tokens;
 * @notice This contract is designed to maintain 1 minted token = 1 BlockDag usd peg through its minting and burning functions.
 * @notice This contract takes native BDAG Token as collateral to mint new Bdag tokens.
 * @notice It is designed to be owned by the LendingPool contract, which will have exclusive rights to mint and burn BDAG tokens.
 * @dev Inherits from OpenZeppelin's ReentrancyGuard to prevent reentrancy attacks.
 */
contract BdagTokenEngine is ReentrancyGuard, ERC20 {
    error BdagTokenEngine__AmountMustBeMoreThanZero();
    error BdagTokenEngine__MintingFailed();
    error BdagTokenEngine__BreaksHealthFactor();
    error BdagTokenEngine__NotEnoughCollateral();
    error BdagTokenEngine__TransferFailed();

    uint256 public constant PRECISION = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50; // 50%
    uint256 public constant LIQUIDATION_PRECISION = 100;
    uint256 public constant MIN_HEALTH_FACTOR = 1; //
    uint256 public constant BDAG_PRICE = 1; // $ 1

    address[] private s_users;

    mapping(address => uint256) private s_collateralBalances;
    mapping(address => uint256) private s_bdagMinted;

    event collateralRedeemed(address indexed user, uint256 amount);
    event collateralDeposited(address indexed user, uint256 amount);

    constructor() ERC20("BDAG", "bDag") { }

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert BdagTokenEngine__AmountMustBeMoreThanZero();
        }
        _;
    }

    function depositCollateralAndMintBdag(uint256 amountCollateral, uint256 amountBdagToMint)
        public
        payable
        moreThanZero(amountBdagToMint)
        moreThanZero(amountCollateral)
    {
        require(msg.value >= amountCollateral * PRECISION, "Incorrect collateral amount sent");
        uint256 weiToEther = msg.value / PRECISION;
        s_collateralBalances[msg.sender] += weiToEther;
        emit collateralDeposited(msg.sender, msg.value);
        mintBdag(amountBdagToMint);
        s_users.push(msg.sender);
    }

    function depositCollateral(uint256 amountCollateral) public payable moreThanZero(amountCollateral) {
        require(msg.value >= amountCollateral * PRECISION, "Incorrect collateral amount sent");
        uint256 weiToEther = msg.value / PRECISION;
        s_collateralBalances[msg.sender] += weiToEther;
        emit collateralDeposited(msg.sender, msg.value);
        s_users.push(msg.sender);
    }

    // function redeemCollateralForBdag(uint256 amountCollateralToRedeem, uint256 amountBdagToBurn) public  {
    //     burnBdag(amountBdagToBurn);
    //     redeemCollateral(amountCollateralToRedeem);
    // }

    function redeemCollateral(uint256 amountCollateralToRedeem) public nonReentrant {
        uint256 userCollateral = s_collateralBalances[msg.sender];
        if (amountCollateralToRedeem > userCollateral) {
            revert BdagTokenEngine__NotEnoughCollateral();
        }
        s_collateralBalances[msg.sender] -= amountCollateralToRedeem;
        emit collateralRedeemed(msg.sender, amountCollateralToRedeem);
        (bool success,) = payable(msg.sender).call{ value: amountCollateralToRedeem * PRECISION }("");
        if (!success) {
            revert BdagTokenEngine__TransferFailed();
        }
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function mintBdag(uint256 amountBdagToMint) public moreThanZero(amountBdagToMint) nonReentrant {
        uint256 collateral = s_collateralBalances[msg.sender];
        require(collateral >= amountBdagToMint, "Insufficient Fund");
        s_bdagMinted[msg.sender] += amountBdagToMint;
        _mint(msg.sender, amountBdagToMint);
        s_collateralBalances[msg.sender] -= amountBdagToMint;
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnBdag(uint256 amountBdagToBurn) public nonReentrant {
        s_bdagMinted[msg.sender] -= amountBdagToBurn;
        _burn(msg.sender, amountBdagToBurn);
        s_collateralBalances[msg.sender] += amountBdagToBurn;
        revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice revertIfHealthFactorIsBroken : This function checks if the user's health factor is above the minimum threshold.
     * @param user The address of the user to check the health factor for.
     * @dev If the health factor is below the minimum threshold, the function reverts with an error.
     */
    function revertIfHealthFactorIsBroken(address user) internal view {
        uint256 healthFactor = _healthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert BdagTokenEngine__BreaksHealthFactor();
        }
    }

    /**
     * @notice _healthFactor : This function calculates the health factor for a user.
     * @param user The address of the user to check the health factor for.
     * @return The health factor of the user, scaled by 1e18 for precision.
     * @dev The health factor is calculated as (collateral value in USD * liquidation threshold) / total BDAG minted.
     * @dev A health factor below 1.0 (1e18) indicates that the user's position is undercollateralized and may be subject to liquidation
     */
    function _healthFactor(address user) public view returns (uint256) {
        (uint256 collateralValueInUsd, uint256 bdagMinted) = _getAccountInfo(user);

        if (bdagMinted == 0) {
            return type(uint256).max;
        }

        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION; // 50% liquidation threshold

        return (collateralAdjustedForThreshold) / bdagMinted;
    }

    function calculateBdagToUsd(uint256 amountBdag) public pure returns (uint256) {
        return (amountBdag * BDAG_PRICE);
    }

    function _getAccountInfo(address user) private view returns (uint256 collateralValueInUsd, uint256 bdagMinted) {
        collateralValueInUsd = calculateBdagToUsd(s_collateralBalances[user]);
        bdagMinted = s_bdagMinted[user];
    }

    function getBalance(address user) public view returns (uint256) {
        user = msg.sender;
        return s_collateralBalances[user];
    }

    function getUserInfo(address user)
        public
        view
        returns (uint256 collateralValueInUsd, uint256 bdagMinted, uint256 healthFactor)
    {
        (collateralValueInUsd, bdagMinted) = _getAccountInfo(user);
        healthFactor = _healthFactor(user);
        return (collateralValueInUsd, bdagMinted, healthFactor);
    }

    function getTotalUsersInTheProtocol() public view returns (uint256) {
        return s_users.length;
    }
}
