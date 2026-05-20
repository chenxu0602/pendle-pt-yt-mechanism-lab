# PT/SY Market Boundary Notes

## Summary

Pendle PT/SY markets are not constant-product AMMs and not Uniswap V3-style concentrated-liquidity markets.

They are two-token markets whose pricing is best interpreted through implied yield.

The key intuition is:

```
PT price up   → implied APY down
PT price down → implied APY up
```

This is closer to fixed-income market logic than generic token spot trading.

## Simplified Model

The simplified harness uses:

```
proportion = totalPt / (totalPt + totalAsset)

exchangeRate = rateAnchor + proportion / rateScalar

PT price ≈ 1 / exchangeRate

impliedApyProxy ≈ (exchangeRate - 1) / timeToExpiry
```

The real Pendle market uses a logit curve rather than the simplified linear proxy:

```
exchangeRate = rateAnchor + logit(proportion) / rateScalar
```

where:

```
logit(p) = ln(p / (1 - p))
```

The simplified harness is intentionally directional. It is designed to test qualitative market behavior before introducing the full Pendle `MarketMathCore`.

It preserves the main monotonic relationships:

```
PT proportion up   → exchangeRate up   → PT price down → implied APY up
PT proportion down → exchangeRate down → PT price up   → implied APY down
```

It does not reproduce production Pendle pricing exactly.

## Test Results

### Buying PT

When a user buys PT:

- pool PT decreases;
- PT proportion decreases;
- exchangeRate decreases;
- PT price increases;
- implied APY decreases.

This matches fixed-income intuition:

```
PT price up → yield down
```

A large PT buy moves price more than a small PT buy because it removes more PT from the pool and pushes the market further along the curve.

### Selling PT

When a user sells PT:

- pool PT increases;
- PT proportion increases;
- exchangeRate increases;
- PT price decreases;
- implied APY increases.

This matches fixed-income intuition:

```
PT price down → yield up
```

A large PT sell moves price more than a small PT sell because it adds more PT to the pool and pushes the market further along the curve.

### Near Expiry

For the same exchange-rate deviation, annualized implied APY is much more sensitive near expiry.

This is because:

```
impliedRate ≈ ln(exchangeRate) / timeToExpiry
```

As `timeToExpiry` becomes small, the annualized rate can move sharply even for small price deviations.

This is important for both security and trading:

- near-expiry markets can show very large annualized APY numbers from small price differences;
- integrations should avoid treating near-expiry implied APY spikes as normal sustainable yield;
- traders should separate true opportunity from annualization artifacts.

## Difference From Uniswap

### Uniswap V2

Uniswap V2 is a generic token spot AMM:

- price comes from reserve ratio;
- invariant is `x * y = k`;
- there is no maturity;
- there is no principal redemption value;
- there is no implied yield.

### Uniswap V3

Uniswap V3 is a concentrated-liquidity spot AMM:

- liquidity is distributed across ticks;
- LPs choose price ranges;
- active liquidity changes as price crosses ticks;
- price movement depends on local liquidity geometry.

### Pendle PT/SY

Pendle PT/SY markets are yield markets:

- PT/SY two-token market;
- custom implied-rate curve;
- time-to-expiry aware;
- PT price movement maps to fixed-yield APY;
- PT price tends toward maturity value if SY backing is sound;
- reserve composition should be interpreted through yield, not just spot price.

A useful summary:

```
Uniswap V2: spot token AMM
Uniswap V3: concentrated-liquidity spot AMM
Pendle: implied-rate AMM for PT/SY yield markets
```

## Security Interpretation

Market boundary behavior matters because external protocols may consume Pendle-derived prices or rates.

Potential hazards:

- using spot-like rates instead of robust oracle rates;
- ignoring oracle readiness and TWAP duration;
- valuing PT as risk-free principal;
- ignoring low-liquidity or near-expiry sensitivity;
- treating implied APY spikes as normal yield instead of stress;
- accepting PT or LP collateral without accounting for liquidity and maturity effects.

The main security question is:

```
Can an external protocol be made to consume a manipulated, stale, or inappropriate PT/SY-derived value?
```

Directly pushing Pendle market price with a large trade is usually costly because the attacker pays slippage and fees.

The more dangerous pattern is:

```
large trade or impaired backing
→ unsafe external valuation
→ collateral overvaluation
→ excess borrowing or bad debt
```

## Alpha Interpretation

Pendle market state can be interpreted as a DeFi yield curve.

Important observables:

- PT implied APY;
- time to expiry;
- PT/SY reserve imbalance;
- liquidity depth;
- maturity roll-down;
- deviation from underlying floating yield;
- sudden implied-rate moves near expiry;
- difference between PT implied APY and perceived underlying risk.

A PT implied APY spike can mean different things:

- attractive fixed-yield opportunity;
- low-liquidity artifact;
- near-expiry annualization artifact;
- SY backing stress;
- depeg or slashing risk premium;
- oracle/integration uncertainty.

The mechanism lab should therefore treat implied APY as a market signal that must be decomposed, not blindly accepted.

## Current Limitations

The current harness is simplified.

It does not reproduce production Pendle math exactly because it uses a linear monotonic proxy instead of the real logit curve.

It does not model:

- real `MarketMathCore`;
- fees;
- reserve fees;
- exact fixed-point log/exp math;
- `PYIndex` conversion;
- PT/SY token transfers;
- router paths;
- TWAP oracle behavior;
- real liquidity distribution across live Pendle markets.

It is designed to test directionality and intuition before introducing the full Pendle `MarketMathCore`.

## Next Step

Possible next steps:

- import selected Pendle market math;
- compare simplified directionality with real Pendle curve behavior;
- add examples with real `rateScalar`, `rateAnchor`, and implied-rate conversion;
- add a notebook pulling live Pendle market data to compare implied APY, maturity, liquidity, and reserve imbalance.