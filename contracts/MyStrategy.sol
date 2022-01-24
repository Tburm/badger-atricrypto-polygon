// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {BaseStrategy} from "@badger-finance/BaseStrategy.sol";
import {ICurveGauge} from "./interfaces/ICurveGauge.sol";
import {ICurvePool} from "./interfaces/ICurvePool.sol";
import {IUniswapRouterV2} from "./interfaces/IUniswapRouterV2.sol";
import {IERC20Upgradeable} from "./interfaces/IERC20Upgradeable.sol";

contract MyStrategy is BaseStrategy {
// address public want; // Inherited from BaseStrategy
    address public lpComponent; // Token we provide liquidity with
    // address public reward; // Token we farm and swap to want / lpComponent

    address public constant wMATIC_TOKEN = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address public constant wBTC_TOKEN = 0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6;
    address public constant wETH_TOKEN = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address public constant CRV_TOKEN = 0x172370d5Cd63279eFa6d502DAB29171933a610AF;
    address constant public BADGER = 0x1FcbE5937B0cc2adf69772D228fA4205aCF4D9b2;

    address public constant CURVE_TRICRYPTO_GAUGE = 0x3B6B158A76fd8ccc297538F454ce7B4787778c7C;
    address public constant CURVE_TRICRYPTO_POOL_DEPOSIT = 0x1d8b86e3D88cDb2d34688e87E72F388Cb541B7C8;
    
    address public constant SUSHI_ROUTER = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;

    /// @dev Initialize the Strategy with security settings as well as tokens
    /// @notice Proxies will set any non constant variable you declare as default value
    /// @dev add any extra changeable variable at end of initializer as shown
    function initialize(address _vault, address[1] memory _wantConfig) public initializer {
        __BaseStrategy_init(_vault);
        /// @dev Add config here
        want = _wantConfig[0];

        IERC20Upgradeable(want).approve(CURVE_TRICRYPTO_GAUGE, type(uint256).max);
        IERC20Upgradeable(wBTC_TOKEN).approve(CURVE_TRICRYPTO_POOL_DEPOSIT, type(uint256).max);

        IERC20Upgradeable(wMATIC_TOKEN).approve(SUSHI_ROUTER, type(uint256).max);
        IERC20Upgradeable(CRV_TOKEN).approve(SUSHI_ROUTER, type(uint256).max);
    }
    
    /// @dev Return the name of the strategy
    function getName() external pure override returns (string memory) {
        return "StrategyCurveBadgerATricrypto2";
    }

    /// @dev Return a list of protected tokens
    /// @notice It's very important all tokens that are meant to be in the strategy to be marked as protected
    /// @notice this provides security guarantees to the depositors they can't be sweeped away
    function getProtectedTokens() public view virtual override returns (address[] memory) {
        address[] memory protectedTokens = new address[](2);
        protectedTokens[0] = want;
        protectedTokens[1] = BADGER;
        return protectedTokens;
    }

    /// @dev Deposit `_amount` of want, investing it to earn yield
    function _deposit(uint256 _amount) internal override {
        ICurveGauge(CURVE_TRICRYPTO_GAUGE).deposit(_amount);
    }

    /// @dev Withdraw all funds, this is used for migrations, most of the time for emergency reasons
    function _withdrawAll() internal override {
        ICurveGauge(CURVE_TRICRYPTO_GAUGE).withdraw(balanceOfPool());
    }

    /// @dev Withdraw `_amount` of want, so that it can be sent to the vault / depositor
    /// @notice just unlock the funds and return the amount you could unlock
    function _withdrawSome(uint256 _amount) internal override returns (uint256) {
        if(_amount > balanceOfPool()) {
            _amount = balanceOfPool();
        }

        ICurveGauge(CURVE_TRICRYPTO_GAUGE).withdraw(_amount);
        return _amount;
    }


    /// @dev Does this function require `tend` to be called?
    function _isTendable() internal override pure returns (bool) {
        return true;
    }

    function _harvest() internal override returns (TokenAmount[] memory harvested) {
        // get balance before operation
        uint256 _before = IERC20Upgradeable(want).balanceOf(address(this));

        // figure out and claim our rewards
        ICurveGauge(CURVE_TRICRYPTO_GAUGE).claim_rewards();

        // get balance of rewards
        uint256 rewardsAmount = IERC20Upgradeable(wMATIC_TOKEN).balanceOf(address(this));
        uint256 crvAmount = IERC20Upgradeable(CRV_TOKEN).balanceOf(address(this));

        // If no reward, then return zero amounts
        harvested = new TokenAmount[](2);
        if (rewardsAmount == 0 && crvAmount == 0) {
            harvested[0] = TokenAmount(wMATIC_TOKEN, 0);
            harvested[1] = TokenAmount(CRV_TOKEN, 0);
            return harvested;
        }

        // Swap WMATIC to wBTC
        if (rewardsAmount > 0) {
            harvested[0] = TokenAmount(wMATIC_TOKEN, rewardsAmount);

            address[] memory path = new address[](2);
            path[0] = wMATIC_TOKEN;
            path[1] = wBTC_TOKEN;

            IUniswapRouterV2(SUSHI_ROUTER).swapExactTokensForTokens(rewardsAmount, 0, path, address(this), now);
        } else {
            harvested[0] = TokenAmount(wMATIC_TOKEN, 0);
        }

        // Swap CRV to wBTC
        if (crvAmount > 0) {
            harvested[1] = TokenAmount(CRV_TOKEN, crvAmount);

            address[] memory path = new address[](3);
            path[0] = CRV_TOKEN;
            path[1] = wETH_TOKEN;
            path[2] = wBTC_TOKEN;

            IUniswapRouterV2(SUSHI_ROUTER).swapExactTokensForTokens(crvAmount, 0, path, address(this), now);
        } else {
            harvested[1] = TokenAmount(CRV_TOKEN, 0);
        }

        // Add liquidity to pool by depositing wBTC
        ICurvePool(CURVE_TRICRYPTO_POOL_DEPOSIT).add_liquidity(
            [0, 0, 0, IERC20Upgradeable(wBTC_TOKEN).balanceOf(address(this)), 0], 0
        );

        // for calculating the amount harvested
        uint256 _after = IERC20Upgradeable(want).balanceOf(address(this));

        // report the amount of want harvested to the sett
        _reportToVault(_after.sub(_before));

        // deposit to earn rewards
        _deposit(balanceOfWant());
        return harvested;
    }

    /// @dev Deposit any leftover want
    function _tend() internal override returns (TokenAmount[] memory tended) {
        uint256 amount = balanceOfWant();
        tended = new TokenAmount[](1);

        if(amount > 0) {
            _deposit(amount);
            tended[0] = TokenAmount(want, amount);
        } else {
            tended[0] = TokenAmount(want, 0);
        }
        return tended;
    }

    /// @dev Return the balance (in want) that the strategy has invested somewhere
    function balanceOfPool() public view override returns (uint256) {
        return IERC20Upgradeable(CURVE_TRICRYPTO_GAUGE).balanceOf(address(this));
    }

    /// @dev Return the balance of rewards that the strategy has accrued
    /// @notice Used for offChain APY and Harvest Health monitoring
    function balanceOfRewards() external view override returns (TokenAmount[] memory rewards) {
        rewards = new TokenAmount[](2);

        rewards[0] = TokenAmount(
            wMATIC_TOKEN,
            IERC20Upgradeable(wMATIC_TOKEN).balanceOf(address(this))
        );
        rewards[1] = TokenAmount(
            CRV_TOKEN,
            IERC20Upgradeable(CRV_TOKEN).balanceOf(address(this))
        );
        return rewards;
    }
}
