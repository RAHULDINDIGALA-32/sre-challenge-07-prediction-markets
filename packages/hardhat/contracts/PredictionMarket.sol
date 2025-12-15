//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { PredictionMarketToken } from "./PredictionMarketToken.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PredictionMarket
 * @author Rahul Dindigala
 *
 * @notice
 * A decentralized, ETH-collateralized binary prediction market.
 *
 * Users can buy and sell outcome tokens (YES / NO) whose prices reflect
 * the market-implied probability of each outcome. After resolution,
 * holders of the winning outcome token can redeem them 1:1 for ETH.
 *
 * @dev
 * - The market uses two ERC20 outcome tokens (YES and NO).
 * - Token prices are derived from a probability curve based on tokens sold.
 * - ETH collateral guarantees redemption of winning tokens.
 * - Initial probabilities are bootstrapped via locked tokens.
 * - Liquidity provisioning and settlement are owner-controlled.
 * - Outcome reporting is oracle-controlled.
 *
 * Security assumptions:
 * - Oracle is trusted to report the correct outcome.
 * - Liquidity provider is trusted not to abuse liquidity controls.
 * - Token minting/burning is strictly limited to this contract.
 */
contract PredictionMarket is Ownable {
    /////////////////
    /// Errors //////
    /////////////////

    error PredictionMarket__MustProvideETHForInitialLiquidity();
    error PredictionMarket__MustProvideETHForLiquidity();
    error PredictionMarket__InvalidETHAmountToWithdraw();
    error PredictionMarket__InvalidProbability();
    error PredictionMarket__PredictionAlreadyReported();
    error PredictionMarket__OnlyOracleCanReport();
    error PredictionMarket__OwnerCannotCall();
    error PredictionMarket__PredictionNotReported();
    error PredictionMarket__InsufficientWinningTokens();
    error PredictionMarket__AmountMustBeGreaterThanZero();
    error PredictionMarket__MustSendExactETHAmount();
    error PredictionMarket__InsufficientTokenReserve(Outcome _outcome, uint256 _amountToken);
    error PredictionMarket__TokenTransferFailed();
    error PredictionMarket__ETHTransferFailed();
    error PredictionMarket__InsufficientBalance(uint256 _tradingAmount, uint256 _userBalance);
    error PredictionMarket__InsufficientAllowance(uint256 _tradingAmount, uint256 _allowance);
    error PredictionMarket__InsufficientLiquidity();
    error PredictionMarket__InvalidPercentageToLock();

    //////////////////////////
    /// State Variables //////
    //////////////////////////

    enum Outcome {
        YES,
        NO
    }

    uint256 private constant PRECISION = 1e18;

    /// Checkpoint 2 ///
    uint256 public s_ethCollateral;
    uint256 public s_lpTradingRevenue;
    address public immutable i_liquidityProvider;
    address public immutable i_oracle;
    string public  s_question;
    uint256 public immutable i_initialTokenValue;
    uint8 public immutable i_initialYesProbability;
    uint8 public immutable i_percentageLocked;

    /// Checkpoint 3 ///
    PredictionMarketToken public immutable i_yesToken;
    PredictionMarketToken public immutable i_noToken;

    /// Checkpoint 5 ///
    PredictionMarketToken public s_winningToken;
    bool public s_isReported;

    /////////////////////////
    /// Events //////
    /////////////////////////

    event TokensPurchased(address indexed buyer, Outcome outcome, uint256 amount, uint256 ethAmount);
    event TokensSold(address indexed seller, Outcome outcome, uint256 amount, uint256 ethAmount);
    event WinningTokensRedeemed(address indexed redeemer, uint256 amount, uint256 ethAmount);
    event MarketReported(address indexed oracle, Outcome winningOutcome, address winningToken);
    event MarketResolved(address indexed resolver, uint256 totalEthToSend);
    event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokensAmount);
    event LiquidityRemoved(address indexed provider, uint256 ethAmount, uint256 tokensAmount);

    /////////////////
    /// Modifiers ///
    /////////////////

    /// Checkpoint 5 ///
    modifier predictionNotReported() {
        if (s_isReported) {
            revert PredictionMarket__PredictionAlreadyReported();
        }
        _;
    }

    modifier onlyOracle() {
        if (msg.sender != i_oracle) {
            revert PredictionMarket__OnlyOracleCanReport();
        }
        _;
    }

    /// Checkpoint 6 ///
    modifier predictionReported() {
        if (!s_isReported) {
            revert PredictionMarket__PredictionNotReported();
        }
        _;
    }


    /// Checkpoint 8 ///
    modifier amountGreaterThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert PredictionMarket__AmountMustBeGreaterThanZero();
        }
        _;
    } 

    modifier notOwner() {
         if (msg.sender == owner()) {
            revert PredictionMarket__OwnerCannotCall();
        }
        _;
    } 

    //////////////////
    ////Constructor///
    //////////////////


    /**
 * @notice
 * Deploys a new prediction market and initializes liquidity, pricing,
 * and probability bootstrapping.
 *
 * @dev
 * - Requires ETH to seed initial liquidity.
 * - Mints equal amounts of YES and NO tokens.
 * - Locks a percentage of tokens to simulate an initial probability.
 * - Locked tokens are held by the market contract and cannot circulate.
 *
 * @param _liquidityProvider Address that owns the market and manages liquidity
 * @param _oracle Address authorized to report the final outcome
 * @param _question Human-readable prediction question
 * @param _initialTokenValue ETH value (scaled by 1e18) of one winning token
 * @param _initialYesProbability Initial YES probability (1–99)
 * @param _percentageToLock Percentage of supply locked to seed probability
 */
    constructor(
        address _liquidityProvider,
        address _oracle,
        string memory _question,
        uint256 _initialTokenValue,
        uint8 _initialYesProbability,
        uint8 _percentageToLock
    ) payable Ownable(_liquidityProvider) {
        /// Checkpoint 2 ////
        if (msg.value == 0) {
            revert PredictionMarket__MustProvideETHForInitialLiquidity();
        }
        if (_initialYesProbability >=100 || _initialYesProbability == 0) {
            revert PredictionMarket__InvalidProbability();
        }
        if (_percentageToLock >=100 || _percentageToLock == 0) {
            revert PredictionMarket__InvalidPercentageToLock();
        }

        i_oracle = _oracle;
        s_question = _question;
        i_initialTokenValue = _initialTokenValue;
        i_initialYesProbability = _initialYesProbability;
        i_percentageLocked = _percentageToLock;
        s_ethCollateral = msg.value;
        i_liquidityProvider = _liquidityProvider;

        /// Checkpoint 3 ////
        uint256 initialTokenAmount = (msg.value * PRECISION) / _initialTokenValue;
        i_yesToken = new PredictionMarketToken("Yes", "Y", _liquidityProvider, initialTokenAmount);
        i_noToken = new PredictionMarketToken("No", "N", _liquidityProvider, initialTokenAmount);
        uint256 initialYesTokenToLock = (initialTokenAmount * _initialYesProbability * _percentageToLock * 2) / 10000;
        uint256 initialNoTokenToLock = (initialTokenAmount * (100 - _initialYesProbability) * _percentageToLock * 2) / 10000;
        
        bool success1 = i_yesToken.transfer(msg.sender, initialYesTokenToLock);
        bool success2 = i_noToken.transfer(msg.sender, initialNoTokenToLock);
        if (!success1 || !success2) {
            revert PredictionMarket__TokenTransferFailed();
        }

    }

    /////////////////
    /// Functions ///
    /////////////////

    /**
     * @notice Add liquidity to the prediction market and mint tokens
     * @dev Only the owner can add liquidity and only if the prediction is not reported
     */
    function addLiquidity() external payable onlyOwner predictionNotReported {
        //// Checkpoint 4 ////
        if (msg.value == 0) {
            revert PredictionMarket__MustProvideETHForLiquidity();
        }
        s_ethCollateral += msg.value;
        uint256 tokensToMint = (msg.value * PRECISION) / i_initialTokenValue;
        i_yesToken.mint(address(this), tokensToMint);
        i_noToken.mint(address(this), tokensToMint);
        emit LiquidityAdded(msg.sender, msg.value, tokensToMint);

    }

    /**
     * @notice Remove liquidity from the prediction market and burn respective tokens, if you remove liquidity before prediction ends you got no share of lpReserve
     * @dev Only the owner can remove liquidity and only if the prediction is not reported
     * @param _ethToWithdraw Amount of ETH to withdraw from liquidity pool
     */
    function removeLiquidity(uint256 _ethToWithdraw) external onlyOwner predictionNotReported {
        //// Checkpoint 4 ////
        // if (_ethToWithdraw == 0 || _ethToWithdraw > s_ethCollateral) {
        //     revert PredictionMarket__InvalidETHAmountToWithdraw();
        // }
        uint256 tokensToBurn = (_ethToWithdraw * PRECISION) / i_initialTokenValue;
        if(tokensToBurn > i_yesToken.balanceOf(address(this)) ) {
            revert PredictionMarket__InsufficientTokenReserve(Outcome.YES, tokensToBurn);
        }
        if (tokensToBurn > i_noToken.balanceOf(address(this))) {
            revert PredictionMarket__InsufficientTokenReserve(Outcome.NO, tokensToBurn);
        }
        s_ethCollateral -= _ethToWithdraw;
        i_yesToken.burn(address(this), tokensToBurn);
        i_noToken.burn(address(this), tokensToBurn);

        (bool success, ) = msg.sender.call{value: _ethToWithdraw}("");
        if (!success) {
            revert PredictionMarket__ETHTransferFailed();
        }
        
        emit LiquidityRemoved(msg.sender, _ethToWithdraw, tokensToBurn);
    }

    /**
     * @notice Report the winning outcome for the prediction
     * @dev Only the oracle can report the winning outcome and only if the prediction is not reported
     * @param _winningOutcome The winning outcome (YES or NO)
     */
    function report(Outcome _winningOutcome) external onlyOracle predictionNotReported {
        //// Checkpoint 5 ////
        s_winningToken  = _winningOutcome == Outcome.YES ? i_yesToken : i_noToken;
        s_isReported = true;

        emit MarketReported(msg.sender, _winningOutcome, address(s_winningToken));
    }

    /**
     * @notice Owner of contract can redeem winning tokens held by the contract after prediction is resolved and get ETH from the contract including LP revenue and collateral back
     * @dev Only callable by the owner and only if the prediction is resolved
     * @return ethRedeemed The amount of ETH redeemed
     */
    function resolveMarketAndWithdraw() external onlyOwner predictionReported returns (uint256 ethRedeemed) {
        /// Checkpoint 6 ////
        uint256 contractWinningTokens = s_winningToken.balanceOf(address(this));
        if(contractWinningTokens > 0) {
            ethRedeemed = (contractWinningTokens * i_initialTokenValue) / PRECISION;

            if (ethRedeemed > s_ethCollateral) {
                ethRedeemed = s_ethCollateral;
            }            

            s_ethCollateral -= ethRedeemed;
        }

        uint256 totalEthToSend = ethRedeemed + s_lpTradingRevenue;
        s_lpTradingRevenue = 0;

        s_winningToken.burn(address(this), contractWinningTokens);

        (bool success, ) = msg.sender.call{value: totalEthToSend}("");
        if(!success) {
            revert PredictionMarket__ETHTransferFailed();
        }

        emit MarketResolved(msg.sender, totalEthToSend);

        return ethRedeemed;
    }

    /**
     * @notice Buy prediction outcome tokens with ETH, need to call priceInETH function first to get right amount of tokens to buy
     * @param _outcome The possible outcome (YES or NO) to buy tokens for
     * @param _amountTokenToBuy Amount of tokens to purchase
     */
    function buyTokensWithETH(Outcome _outcome, uint256 _amountTokenToBuy) external payable predictionNotReported amountGreaterThanZero(_amountTokenToBuy) notOwner {
        /// Checkpoint 8 ////
        (uint256 currentTokenReserves, ) = _getCurrentReserves(_outcome);
       if (_amountTokenToBuy > currentTokenReserves) {
           revert PredictionMarket__InsufficientTokenReserve(_outcome, _amountTokenToBuy);
       }
        uint256 amountEthRequired = getBuyPriceInEth(_outcome, _amountTokenToBuy);
        if(msg.value != amountEthRequired) {
            revert PredictionMarket__MustSendExactETHAmount();
        }

        s_lpTradingRevenue += msg.value;
        bool success = _outcome == Outcome.YES ? i_yesToken.transfer(msg.sender, _amountTokenToBuy) : i_noToken.transfer(msg.sender, _amountTokenToBuy);
        if (!success) {
            revert PredictionMarket__TokenTransferFailed();
        }

        emit TokensPurchased(msg.sender, _outcome, _amountTokenToBuy, msg.value);
    }

    /**
     * @notice Sell prediction outcome tokens for ETH, need to call priceInETH function first to get right amount of tokens to buy
     * @param _outcome The possible outcome (YES or NO) to sell tokens for
     * @param _tradingAmount The amount of tokens to sell
     */
    function sellTokensForEth(Outcome _outcome, uint256 _tradingAmount) external predictionNotReported amountGreaterThanZero(_tradingAmount) notOwner {
        /// Checkpoint 8 ////
        (uint256 userTokenBalance, uint256 userTokenAllowance) = _outcome == Outcome.YES ? (i_yesToken.balanceOf(msg.sender), i_yesToken.allowance(msg.sender, address(this))) : (i_noToken.balanceOf(msg.sender), i_noToken.allowance(msg.sender, address(this)));
    
        if (_tradingAmount > userTokenBalance) {
            revert PredictionMarket__InsufficientBalance(_tradingAmount, userTokenBalance);
        }
        if (_tradingAmount > userTokenAllowance) {
            revert PredictionMarket__InsufficientAllowance(_tradingAmount, userTokenAllowance);
        }

        uint256 amountEthToSend = getSellPriceInEth(_outcome, _tradingAmount);
        s_lpTradingRevenue -= amountEthToSend;
        
        (bool sent, ) = msg.sender.call{value: amountEthToSend}("");
        if (!sent) {
            revert PredictionMarket__ETHTransferFailed();
        }

        bool success = _outcome == Outcome.YES ? i_yesToken.transferFrom(msg.sender, address(this), _tradingAmount) : i_noToken.transferFrom(msg.sender, address(this), _tradingAmount);
        if (!success) {
            revert PredictionMarket__TokenTransferFailed();
        }

        emit TokensSold(msg.sender, _outcome, _tradingAmount, amountEthToSend);
     }

    /**
     * @notice Redeem winning tokens for ETH after prediction is resolved, winning tokens are burned and user receives ETH
     * @dev Only if the prediction is resolved
     * @param _amount The amount of winning tokens to redeem
     */
    function redeemWinningTokens(uint256 _amount) external predictionReported amountGreaterThanZero(_amount) notOwner {
        /// Checkpoint 9 ////
        uint256 userWinningTokens = s_winningToken.balanceOf(msg.sender);
        if(_amount > userWinningTokens) {
            revert PredictionMarket__InsufficientWinningTokens();
        }

        uint256 totalEthToSend = (_amount * i_initialTokenValue) / PRECISION;

        s_ethCollateral -= totalEthToSend;
        s_winningToken.burn(msg.sender, _amount);

        (bool success, ) = msg.sender.call{value: totalEthToSend}("");
        if (!success) {
            revert PredictionMarket__ETHTransferFailed();
        }
        
        emit WinningTokensRedeemed(msg.sender, _amount, totalEthToSend);      
    }

    /**
     * @notice Calculate the total ETH price for buying tokens
     * @param _outcome The possible outcome (YES or NO) to buy tokens for
     * @param _tradingAmount The amount of tokens to buy
     * @return The total ETH price
     */
    function getBuyPriceInEth(Outcome _outcome, uint256 _tradingAmount) public view returns (uint256) {
        /// Checkpoint 7 ////
        return _calculatePriceInEth(_outcome, _tradingAmount, false);
    }

    /**
     * @notice Calculate the total ETH price for selling tokens
     * @param _outcome The possible outcome (YES or NO) to sell tokens for
     * @param _tradingAmount The amount of tokens to sell
     * @return The total ETH price
     */
    function getSellPriceInEth(Outcome _outcome, uint256 _tradingAmount) public view returns (uint256) {
        /// Checkpoint 7 ////
         return _calculatePriceInEth(_outcome, _tradingAmount, true);
    }

    /////////////////////////
    /// Helper Functions ///
    ////////////////////////

    /**
     * @dev Internal helper to calculate ETH price for both buying and selling
     * @param _outcome The possible outcome (YES or NO)
     * @param _tradingAmount The amount of tokens
     * @param _isSelling Whether this is a sell calculation
     */
    function _calculatePriceInEth(
        Outcome _outcome,
        uint256 _tradingAmount,
        bool _isSelling
    ) private view returns (uint256) {
        /// Checkpoint 7 ////
        (uint256 currentTokenReserve, uint256 currentOtherTokenReserve) = _getCurrentReserves(_outcome);
        if(!_isSelling) {
            if(currentTokenReserve < _tradingAmount) {
                revert PredictionMarket__InsufficientLiquidity();
            }
        }

        uint256 totalTokenSupply = i_yesToken.totalSupply();

        // Before Trade
        uint256 currentTokenSoldBefore = totalTokenSupply - currentTokenReserve;
        uint256 currentOtherTokenSold = totalTokenSupply - currentOtherTokenReserve;

        uint256 totalTokensSoldBefore = currentTokenSoldBefore + currentOtherTokenSold;
        uint256 probabilityBefore = _calculateProbability(currentTokenSoldBefore, totalTokensSoldBefore);

        // After Trade
        uint256 currentTokenReserveAfter = _isSelling ? currentTokenReserve + _tradingAmount : currentTokenReserve - _tradingAmount;
        uint256 currentTokenSoldAfter = totalTokenSupply - currentTokenReserveAfter;
        uint256 totalTokensSoldAfter = _isSelling ? totalTokensSoldBefore - _tradingAmount : totalTokensSoldBefore + _tradingAmount;
        uint256 probabilityAfter = _calculateProbability(currentTokenSoldAfter, totalTokensSoldAfter);

        uint256 probabilityAvg = (probabilityBefore + probabilityAfter) / 2;
        return (i_initialTokenValue * probabilityAvg * _tradingAmount) / (PRECISION * PRECISION);

    }

    /**
     * @dev Internal helper to get the current reserves of the tokens
     * @param _outcome The possible outcome (YES or NO)
     * @return The current reserves of the tokens
     */
    function _getCurrentReserves(Outcome _outcome) private view returns (uint256, uint256) {
        /// Checkpoint 7 ////
        if (_outcome == Outcome.YES) {
            return (i_yesToken.balanceOf(address(this)), i_noToken.balanceOf(address(this)));
        } else {
            return (i_noToken.balanceOf(address(this)), i_yesToken.balanceOf(address(this)));
        }
    }

    /**
     * @dev Internal helper to calculate the probability of the tokens
     * @param tokensSold The number of tokens sold
     * @param totalSold The total number of tokens sold
     * @return The probability of the tokens
     */
    function _calculateProbability(uint256 tokensSold, uint256 totalSold) private pure returns (uint256) {
        /// Checkpoint 7 ////
        uint256 probability = (tokensSold * PRECISION) / totalSold;
        return probability;
    }

    /////////////////////////
    /// Getter Functions ///
    ////////////////////////

    /**
     * @notice Get the prediction details
     */
    function getPrediction()
        external
        view
        returns (
            string memory question,
            string memory outcome1,
            string memory outcome2,
            address oracle,
            uint256 initialTokenValue,
            uint256 yesTokenReserve,
            uint256 noTokenReserve,
            bool isReported,
            address yesToken,
            address noToken,
            address winningToken,
            uint256 ethCollateral,
            uint256 lpTradingRevenue,
            address predictionMarketOwner,
            uint256 initialProbability,
            uint256 percentageLocked
        )
    {
        /// Checkpoint 3 ////
        oracle = i_oracle;
        initialTokenValue = i_initialTokenValue;
        percentageLocked = i_percentageLocked;
        initialProbability = i_initialYesProbability;
        question = s_question;
        ethCollateral = s_ethCollateral;
        lpTradingRevenue = s_lpTradingRevenue;
        predictionMarketOwner = owner();
        yesToken = address(i_yesToken);
        noToken = address(i_noToken);
        outcome1 = i_yesToken.name();
        outcome2 = i_noToken.name();
        yesTokenReserve = i_yesToken.balanceOf(address(this));
        noTokenReserve = i_noToken.balanceOf(address(this));
        /// Checkpoint 5 ////
        isReported = s_isReported;
        winningToken = address(s_winningToken);
    }  



}
