# Pendle PT/YT Mechanism Study

## 1. Summary

This study analyzes Pendle-style PT/YT yield-tokenization systems through executable Foundry experiments.

The goal is not to claim a vulnerability in Pendle Finance. The goal is to isolate several mechanism-level behaviors that matter for security, integration, and trading research:

- SY exchange-rate changes;
- monotonic PY index behavior;
- accounting index versus current recoverable backing;
- unsafe oracle consumer overvaluation;
- lending bad-debt potential under severe SY impairment;
- PT/SY implied-rate market behavior.

The core conclusion is:

> A Pendle-style PY index floor can be a valid accounting design, but external protocols must not treat a floored accounting index as current recoverable collateral value during SY impairment.

A second conclusion is:

> Pendle PT/SY markets should be understood as implied-yield markets, not as generic spot AMMs.

The current lab contains 12 passing Foundry tests across four experiment groups.

## 2. Pendle-Style Yield Tokenization

Pendle-style systems decompose a yield-bearing asset into principal and yield components.

The simplified flow is:

```
yield-bearing asset
→ SY
→ PT + YT
```

Where:

- **SY** is a standardized wrapper around a yield-bearing asset.
- **PT** is the principal-like claim.
- **YT** is the yield-side claim.
- **LP** represents liquidity provision in a PT/SY market.

Before expiry, a matching PT + YT position can be redeemed back into SY according to protocol rules.

After expiry, PT becomes the main redemption-side claim, while YT no longer has principal value. YT may still be relevant for previously accrued interest or rewards depending on protocol mechanics.

A useful but incomplete market relation is:

```
SY ≈ PT + YT
```

This is an accounting and conversion relation, not a guarantee that market prices will always satisfy exact equality.

At the market layer:

```
Value(SY) ≈ Value(PT) + Value(YT)
```

but fees, slippage, liquidity, points expectations, rewards, time to expiry, and exchange-rate uncertainty can create deviations.

## 3. PT Is Principal-Like, Not Risk-Free

PT is often described as similar to a zero-coupon bond.

That analogy is useful because:

- PT trades below maturity value before expiry;
- PT price tends to rise toward redemption value as maturity approaches;
- PT implied APY can be interpreted like a fixed-yield rate.

However, PT is not risk-free.

A more precise model is:

```
PT = principal-like claim on risky SY backing
```

PT remains exposed to:

- SY adapter risk;
- underlying asset depeg;
- slashing;
- external protocol loss;
- redemption impairment;
- oracle or exchange-rate error;
- liquidity stress;
- maturity and expiry boundary handling.

If SY backing remains sound, PT behaves like a fixed-yield principal claim.

If SY backing is impaired, PT holders can lose value.

This distinction is central to the lab.

## 4. PY Index as a Monotonic Accounting Index

The PY index converts between SY and PT/YT accounting units.

The simplified rule studied in this lab is:

```
pyIndexCurrent = max(current SY exchangeRate, pyIndexStored)
```

This means:

```
SY exchangeRate rises
→ PY index follows upward

SY exchangeRate falls
→ PY index does not decrease
```

This is not assumed to be a bug.

A monotonic PY index can be a reasonable accounting design because it avoids retroactively decreasing previously accrued yield accounting.

If the PY index were allowed to decrease freely, it would raise difficult questions:

- Should previously accrued YT interest be reversed?
- Can already claimed rewards become negative?
- Do transferred PT/YT positions inherit prior losses differently?
- Does redemption become path-dependent?
- How should external oracle consumers interpret a decreasing accounting index?

The PY index floor is therefore best understood as an accounting design choice.

The security question is not:

> Should the PY index decrease?

The more important question is:

> Which downstream paths treat the accounting index as current recoverable value?

## 5. Accounting Index Versus Recoverable Backing

The first experiment models the following path:

```
SY exchangeRate: 1.00 → 1.10 → 0.95
PY index:        1.00 → 1.10 → 1.10
```

After the exchange-rate decrease:

```
current SY exchangeRate = 0.95
pyIndexStored           = 1.10
stress gap              = 0.15
```

For `100 SY`:

```
recoverable backing at current SY exchangeRate = 95
PY accounting amount using floored index       = 110
```

This is the key distinction:

```
pyIndexStored = accounting index
current SY exchangeRate = current backing / recoverable value proxy
```

A divergence between these two values is not automatically a protocol bug.

It is a stress state.

That stress state becomes dangerous when an external integration treats the accounting index as if it were current recoverable collateral value.

## 6. Experiment 1: PY Index Floor

The first experiment uses:

- `MockSY`
- `PyIndexHarness`
- `test/PyIndexFloor.t.sol`

The test suite confirms:

- the initial PY index equals the initial SY exchange rate;
- the PY index increases when SY exchange rate increases;
- the PY index does not decrease when SY exchange rate falls;
- the accounting index can diverge from current recoverable backing.

The main result is:

```
SY exchangeRate = 0.95
PY index        = 1.10
```

For `100 SY`:

```
recoverable backing = 95
accounting value    = 110
```

The experiment demonstrates the mechanism-level divergence between accounting value and recoverable backing.

It does not claim that the PY index floor is itself a vulnerability.

## 7. Experiment 2: Unsafe Oracle Consumer Overvaluation

The second experiment adds:

- `UnsafeOracleConsumer`
- `test/OracleConsumerOvervaluation.t.sol`

The unsafe consumer values collateral using the floored PY index:

```
unsafe value = syAmount * pyIndexCurrent
```

The safer baseline uses the current SY exchange rate:

```
recoverable value = syAmount * currentSyExchangeRate
```

Under the stress path:

```
SY exchangeRate = 0.95
PY index        = 1.10
```

For `100 SY`:

```
unsafe value using PY index             = 110
recoverable value using current SY rate = 95
overvaluation                           = 15
```

This experiment shows the integration hazard:

> A monotonic accounting index can be correct internally, while still being unsafe as a proxy for current recoverable collateral value.

The issue is not the existence of the PY index floor.

The issue is using the wrong value for the wrong purpose.

## 8. Experiment 3: Mock Lending Over-Borrow and Bad Debt

The third experiment adds:

- `MockLendingProtocol`
- `test/MockLendingOvervaluation.t.sol`

The mock lending protocol accepts SY-denominated collateral and uses the unsafe oracle consumer for collateral valuation.

The protocol uses 80% LTV.

### Mild Impairment Case

Stress path:

```
current SY exchangeRate = 0.95
PY index                = 1.10
```

For `100 SY` collateral:

```
unsafe collateral value = 110
recoverable value       = 95
```

At 80% LTV:

```
unsafe borrow limit = 88
safe borrow limit   = 76
excess borrow       = 12
```

This case violates the intended safe LTV under recoverable-value accounting.

However, it does not create immediate bad debt because:

```
debt = 88
recoverable collateral value = 95
```

The account is over-levered relative to the intended LTV, but debt remains below recoverable collateral value.

### Severe Impairment Case

Stress path:

```
current SY exchangeRate = 0.60
PY index                = 1.10
```

For `100 SY` collateral:

```
unsafe collateral value = 110
recoverable value       = 60
```

At 80% LTV:

```
unsafe borrow limit = 88
safe borrow limit   = 48
excess borrow       = 40
```

If the borrower borrows up to the unsafe limit:

```
debt = 88
recoverable collateral value = 60
bad-debt gap = 28
```

This is the stronger attack-path demonstration.

It shows that under severe SY impairment, unsafe PY-index-based valuation can allow debt to exceed current recoverable collateral value.

The resulting bad debt is not caused by the PY index floor alone.

It is caused by an external integration using an accounting index as collateral value.

## 9. Economic Condition for Attacker Profit

Unsafe valuation does not automatically imply attacker profit.

Profit requires that the attacker can obtain collateral at or near impaired fair value while the external protocol values it closer to the accounting index.

A simplified condition is:

```
borrowed assets > acquisition cost of collateral + costs
```

A weaker condition is:

```
borrowed assets > safe borrow limit
```

This indicates unsafe leverage relative to recoverable backing, but not necessarily direct bad debt.

A stronger condition is:

```
borrowed assets > recoverable collateral value
```

This indicates immediate bad-debt potential.

The lab demonstrates both cases:

- mild impairment creates excess borrow capacity relative to intended safe LTV;
- severe impairment creates direct bad-debt potential.

## 10. Loss Allocation Under SY Impairment

If SY exchange rate falls because of real underlying impairment, the system is not zero-sum inside Pendle-style contracts.

Total recoverable value has decreased.

The question becomes:

> Who absorbs the loss, and can anyone transfer that loss elsewhere?

Potential affected parties include:

- PT holders;
- YT holders;
- LPs;
- traders;
- external lending protocols;
- vaults;
- oracle consumers.

### PT Holders

PT holders own principal-like claims.

If backing is sound, PT resembles a fixed-yield principal asset.

If backing is impaired, PT holders can lose value.

### YT Holders

YT is the yield-side exposure.

It is usually more junior and more sensitive to:

- lower future yield;
- reward decline;
- points repricing;
- time decay;
- underlying impairment.

### LPs

LPs hold mixed PT/SY exposure through the market.

Their loss depends on:

- PT/SY reserve composition;
- exit timing;
- market price adjustment;
- oracle valuation;
- liquidity depth.

### Traders

Informed traders can profit or avoid losses by selling, hedging, or avoiding exposure before impairment is fully priced.

### External Integrators

The largest security issue may appear outside the core protocol.

If external protocols overvalue PT, SY, or LP collateral, attackers can transfer losses to those protocols by borrowing against mispriced collateral.

## 11. PT/SY Market Mechanics

Pendle V2 markets are primarily PT/SY markets.

They are not PT/YT pools.

The core market pair is:

```
PT / SY
```

YT exposure is synthesized through composition:

```
Long YT ≈ Long SY - Long PT
```

A user can buy YT exposure by:

```
start with SY
→ mint PT + YT
→ sell PT into the PT/SY market
→ keep YT
```

The SY received from selling PT represents recovered principal value and may be recursively reused by router or zap logic.

This is why Pendle does not need a direct PT/YT AMM for the main market design.

## 12. Experiment 4: PT/SY Market Boundary

The fourth experiment uses:

- `SimplifiedMarketMathHarness`
- `test/MarketBoundary.t.sol`

The simplified harness is not production Pendle math.

It uses a directional approximation:

```
proportion = totalPt / (totalPt + totalAsset)

exchangeRate = rateAnchor + proportion / rateScalar

PT price ≈ 1 / exchangeRate

impliedApyProxy ≈ (exchangeRate - 1) / timeToExpiry
```

The real Pendle market uses a logit curve:

```
exchangeRate = rateAnchor + logit(proportion) / rateScalar
```

where:

```
logit(p) = ln(p / (1 - p))
```

The simplified harness preserves the key directionality:

```
PT proportion up   → exchangeRate up   → PT price down → implied APY up
PT proportion down → exchangeRate down → PT price up   → implied APY down
```

### Buying PT

When a user buys PT:

```
pool PT decreases
→ PT proportion decreases
→ exchangeRate decreases
→ PT price increases
→ implied APY decreases
```

This matches fixed-income intuition:

```
PT price up → yield down
```

### Selling PT

When a user sells PT:

```
pool PT increases
→ PT proportion increases
→ exchangeRate increases
→ PT price decreases
→ implied APY increases
```

This matches fixed-income intuition:

```
PT price down → yield up
```

### Near Expiry

For the same exchange-rate deviation, annualized implied APY is more sensitive near expiry.

This is because:

```
impliedRate ≈ ln(exchangeRate) / timeToExpiry
```

As `timeToExpiry` becomes small, even small price differences can map to large annualized implied APY values.

This matters because near-expiry APY spikes can be:

- real fixed-yield opportunities;
- low-liquidity artifacts;
- annualization artifacts;
- stress signals;
- oracle or integration hazards.

## 13. Difference From Uniswap

### Uniswap V2

Uniswap V2 is a generic spot AMM:

- price comes from reserve ratio;
- invariant is `x * y = k`;
- there is no maturity;
- there is no implied yield;
- there is no principal redemption value.

### Uniswap V3

Uniswap V3 is a concentrated-liquidity spot AMM:

- liquidity is distributed across ticks;
- LPs choose price ranges;
- active liquidity changes as price crosses ticks;
- price movement depends on local liquidity geometry.

### Pendle PT/SY

Pendle PT/SY markets are implied-yield markets:

- two-token PT/SY market;
- custom implied-rate curve;
- time-to-expiry aware pricing;
- PT price movement maps to fixed-yield APY;
- PT price tends toward maturity value if SY backing is sound;
- reserve composition should be interpreted through yield, not just spot price.

A useful summary is:

```
Uniswap V2 = spot token AMM
Uniswap V3 = concentrated-liquidity spot AMM
Pendle     = implied-rate AMM for PT/SY yield markets
```

## 14. Security Takeaways

The lab highlights several security-relevant conclusions.

### 1. Accounting index is not the same as recoverable value

A monotonic PY index can preserve accounting consistency, but it should not automatically be used as current collateral value.

### 2. PT is not risk-free

PT is principal-like, but still exposed to the backing quality of the underlying SY.

### 3. Unsafe external integrations can create bad debt

If an external protocol values impaired collateral using a floored accounting index, it can allow excess borrowing or direct bad debt.

### 4. Pendle market prices should be consumed carefully

Spot-like rates, near-expiry implied APY, low-liquidity markets, and raw PT/SY-derived values can be unsafe for collateral systems.

### 5. The most dangerous failures may be external

Core protocol behavior can be internally consistent while external consumers misinterpret the meaning of accounting values, oracle rates, or PT/LP prices.

## 15. Alpha Takeaways

The same mechanics can be interpreted as market signals.

Important observables include:

- PT implied APY;
- time to expiry;
- PT/SY reserve imbalance;
- liquidity depth;
- maturity roll-down;
- underlying floating yield;
- PY index versus current SY exchange-rate gap;
- SY depeg or slashing risk;
- oracle readiness;
- LP valuation under stress.

A high PT implied APY may represent:

- attractive fixed yield;
- liquidity shortage;
- near-expiry annualization artifact;
- SY backing stress;
- depeg/slashing risk premium;
- market uncertainty around points or rewards;
- collateral or oracle integration risk.

The lab treats protocol mechanics as both:

- a security surface;
- a market-structure signal.

## 16. Current Test Coverage

Current tests:

- `PyIndexFloor.t.sol`
- `OracleConsumerOvervaluation.t.sol`
- `MockLendingOvervaluation.t.sol`
- `MarketBoundary.t.sol`

Current result:

```
12 tests passed
0 failed
0 skipped
```

Covered behaviors:

- PY index follows SY exchange-rate increases;
- PY index does not decrease when SY exchange rate falls;
- accounting value can diverge from current recoverable backing;
- unsafe oracle consumer can overvalue collateral;
- mild impairment creates excess borrow capacity;
- severe impairment creates direct bad-debt potential;
- buying PT raises PT price and lowers implied APY;
- selling PT lowers PT price and raises implied APY;
- near-expiry annualized implied APY is more sensitive.

## 17. Limitations

This lab is intentionally simplified.

It does not yet model:

- full Pendle `PendleYieldToken`;
- full PT/YT mint and redeem implementation;
- real `MarketMathCore`;
- real Pendle oracle libraries;
- exact fixed-point log/exp math;
- fees and reserve fees;
- router and zap paths;
- real SY adapters;
- reward distribution;
- live market liquidity;
- external liquidation mechanics.

The market-boundary harness uses a linear monotonic proxy instead of the real Pendle logit curve.

The lending protocol is a toy integration designed to isolate collateral valuation failure.

The results should therefore be interpreted as mechanism and integration studies, not claims about a live Pendle vulnerability.

## 18. Next Steps

Possible follow-up work:

1. Real Pendle math comparison
   - Import selected `MarketMathCore` functions.
   - Compare the simplified harness directionality against real Pendle math.

2. PT-specific collateral model
   - Extend the mock lending example from SY-denominated collateral to PT-like collateral.
   - Model PT acquisition cost and recoverable value more explicitly.

3. LP collateral valuation
   - Add toy LP valuation under impaired SY backing.
   - Study whether unsafe LP valuation can create similar over-borrow paths.

4. Python market-data notebook
   - Pull live Pendle market data.
   - Track PT implied APY, maturity, liquidity, and reserve imbalance.
   - Compare implied fixed yield against underlying floating yield and stress proxies.

5. Medium article
   - Convert this study into a public article focused on:
     - PT as principal-like but not risk-free;
     - accounting index versus recoverable backing;
     - unsafe external integrations;
     - Pendle PT/SY markets as implied-yield AMMs.

## 19. Final Conclusion

Pendle-style PT/YT systems do not eliminate underlying asset risk.

They repackage it across:

- principal-like claims;
- yield claims;
- liquidity positions;
- market prices;
- oracle rates;
- external integrations.

The most important distinction in this lab is:

```
accounting value != current recoverable backing
```

A monotonic PY index can be internally reasonable, while still being unsafe for external collateral valuation if used incorrectly.

Similarly, PT can behave like a fixed-income asset when backing is sound, but it is not risk-free.

For security researchers, the key question is:

> Can any protocol path or external integration mistake accounting value for recoverable value?

For traders, the key question is:

> Is the implied APY compensation for yield, liquidity, maturity, or hidden backing risk?

This is why Pendle-style mechanisms should be studied as both financial accounting systems and market-structure systems.