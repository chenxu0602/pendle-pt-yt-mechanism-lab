// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {SimplifiedMarketMathHarness} from "../src/harness/SimplifiedMarketMathHarness.sol";

contract MarketBoundaryTest is Test {
    uint256 internal constant ONE = 1e18;

    SimplifiedMarketMathHarness internal marketMath;

    function setUp() public {
        marketMath = new SimplifiedMarketMathHarness();
    }

    function _baseMarket() internal pure returns (SimplifiedMarketMathHarness.Market memory market) {
        market = SimplifiedMarketMathHarness.Market({
            totalPt: 100e18,
            totalAsset: 100e18,
            rateScalar: 10e18,
            rateAnchor: 1e18,
            timeToExpiry: 180 days
        });
    }

    function test_buyingPtRaisesPtPriceAndLowersImpliedApy() public view {
        SimplifiedMarketMathHarness.Market memory beforeMarket = _baseMarket();

        SimplifiedMarketMathHarness.MarketView memory beforeView = marketMath.getView(beforeMarket);

        SimplifiedMarketMathHarness.Market memory afterMarket = marketMath.buyPt(beforeMarket, 10e18);
        SimplifiedMarketMathHarness.MarketView memory afterView = marketMath.getView(afterMarket);

        // Buying PT removes PT from the pool.
        assertEq(afterMarket.totalPt, 90e18);

        // PT proportion decreases.
        assertLt(afterView.proportion, beforeView.proportion);

        // In this simplified Pendle-style curve:
        // lower PT proportion -> lower exchangeRate.
        assertLt(afterView.exchangeRate, beforeView.exchangeRate);

        // Since PT price ~= 1 / exchangeRate,
        // lower exchangeRate -> higher PT price.
        assertGt(afterView.ptPrice, beforeView.ptPrice);

        // Lower exchangeRate also means lower implied APY.
        assertLt(afterView.impliedApyProxy, beforeView.impliedApyProxy);
    }

    function test_sellingPtLowersPtPriceAndRaisesImpliedApy() public view {
        SimplifiedMarketMathHarness.Market memory beforeMarket = _baseMarket();

        SimplifiedMarketMathHarness.MarketView memory beforeView = marketMath.getView(beforeMarket);

        SimplifiedMarketMathHarness.Market memory afterMarket = marketMath.sellPt(beforeMarket, 10e18);
        SimplifiedMarketMathHarness.MarketView memory afterView = marketMath.getView(afterMarket);

        // Selling PT adds PT to the pool.
        assertEq(afterMarket.totalPt, 110e18);

        // PT proportion increases.
        assertGt(afterView.proportion, beforeView.proportion);

        // Higher PT proportion -> higher exchangeRate.
        assertGt(afterView.exchangeRate, beforeView.exchangeRate);

        // Since PT price ~= 1 / exchangeRate,
        // higher exchangeRate -> lower PT price.
        assertLt(afterView.ptPrice, beforeView.ptPrice);

        // Higher exchangeRate also means higher implied APY.
        assertGt(afterView.impliedApyProxy, beforeView.impliedApyProxy);
    }

    function test_nearExpiryMakesAnnualizedApyMoreSensitive() public view {
        uint256 exchangeRate = 1.01e18;

        uint256 longMaturityApy = marketMath.impliedApyProxyAtMaturity(exchangeRate, 180 days);
        uint256 shortMaturityApy = marketMath.impliedApyProxyAtMaturity(exchangeRate, 7 days);

        assertGt(shortMaturityApy, longMaturityApy);
    }

    function test_extremePtBuyMovesPriceMoreThanSmallPtBuy() public view {
        SimplifiedMarketMathHarness.Market memory beforeMarket = _baseMarket();

        SimplifiedMarketMathHarness.MarketView memory beforeView = marketMath.getView(beforeMarket);

        SimplifiedMarketMathHarness.Market memory smallBuyMarket = marketMath.buyPt(beforeMarket, 5e18);
        SimplifiedMarketMathHarness.Market memory largeBuyMarket = marketMath.buyPt(beforeMarket, 40e18);

        SimplifiedMarketMathHarness.MarketView memory smallBuyView = marketMath.getView(smallBuyMarket);
        SimplifiedMarketMathHarness.MarketView memory largeBuyView = marketMath.getView(largeBuyMarket);

        uint256 smallPriceIncrease = smallBuyView.ptPrice - beforeView.ptPrice;
        uint256 largePriceIncrease = largeBuyView.ptPrice - beforeView.ptPrice;

        assertGt(largePriceIncrease, smallPriceIncrease);
        assertGt(largeBuyView.ptPrice, smallBuyView.ptPrice);
        assertLt(largeBuyView.impliedApyProxy, smallBuyView.impliedApyProxy);
    }

    function test_extremePtSellMovesPriceMoreThanSmallPtSell() public view {
        SimplifiedMarketMathHarness.Market memory beforeMarket = _baseMarket();

        SimplifiedMarketMathHarness.MarketView memory beforeView = marketMath.getView(beforeMarket);

        SimplifiedMarketMathHarness.Market memory smallSellMarket = marketMath.sellPt(beforeMarket, 5e18);
        SimplifiedMarketMathHarness.Market memory largeSellMarket = marketMath.sellPt(beforeMarket, 40e18);

        SimplifiedMarketMathHarness.MarketView memory smallSellView = marketMath.getView(smallSellMarket);
        SimplifiedMarketMathHarness.MarketView memory largeSellView = marketMath.getView(largeSellMarket);

        uint256 smallPriceDecrease = beforeView.ptPrice - smallSellView.ptPrice;
        uint256 largePriceDecrease = beforeView.ptPrice - largeSellView.ptPrice;

        assertGt(largePriceDecrease, smallPriceDecrease);
        assertLt(largeSellView.ptPrice, smallSellView.ptPrice);
        assertGt(largeSellView.impliedApyProxy, smallSellView.impliedApyProxy);
    }
}