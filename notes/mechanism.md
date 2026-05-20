# Pendle PT/YT Mechanism Notes

## 1. Mental Model

Pendle tokenizes yield-bearing assets into two claims:

- **PT**: principal token
- **YT**: yield token

A user starts with a yield-bearing asset or base asset, deposits it into a Standardized Yield wrapper, and receives SY. SY can then be split into PT and YT for a fixed maturity.

```
yield-bearing asset
→ SY
→ PT + YT
```

Before expiry:

```
PT + YT
→ SY
```

After expiry:

```
PT
→ SY / asset-equivalent principal

YT
→ no principal claim, but may have accrued interest/rewards before expiry
```

The key mechanism is that PT and YT are not priced against each other directly. Pendle V2 markets are primarily PT/SY markets.

```
Market pair = PT + SY
```

YT exposure can be synthesized because:

```
SY ≈ PT + YT
```

A user can buy YT by minting PT + YT from SY, selling PT into the PT/SY market, and keeping the YT exposure.

## 2. Main Accounting Layers

Pendle moves value across several denominations:

1. External token or yield-bearing asset
2. SY share
3. Asset unit through SY exchange rate / PY index
4. PT balance
5. YT balance
6. LP share
7. Oracle asset-denominated rate

The main research question is whether these layers preserve value consistently under normal and stressed states.

## 3. Standardized Yield

SY is the adapter layer.

It provides a common interface around heterogeneous yield-bearing assets.

Important operations:

- deposit external asset into SY;
- redeem SY into external asset;
- preview deposit;
- preview redeem;
- report exchange rate;
- claim rewards.

Security-sensitive assumptions:

- preview and execution should be consistent in the same state;
- exchange rate should be reliable or explicitly handle non-monotonic behavior;
- deposit/redeem should account for fees, rebasing, external share-price changes, and delayed withdrawals;
- external protocol losses should not be hidden from downstream consumers.

## 4. PY Index

The PY index converts between SY and PT/YT accounting units.

A central property is monotonicity:

```
pyIndexCurrent = max(current SY exchangeRate, stored PY index)
```

This means:

- when SY exchange rate increases, PY index follows upward;
- when SY exchange rate decreases, PY index does not decrease.

This is an intentional design choice. It is not assumed to be a bug.

However, it creates an important stress case:

```
SY exchangeRate rises from 1.00 to 1.10
PY index rises to 1.10

SY exchangeRate later falls to 0.95
PY index remains 1.10
```

The lab focuses on understanding who absorbs the loss when current SY backing falls below the floored PY index.

## 5. PT

PT represents the principal side of the position.

A simplified fixed-income interpretation:

```
PT current price < 1 asset before expiry
PT value converges toward 1 asset at expiry if SY backing is sound
```

Approximate relation:

```
PT price ≈ exp(-impliedRate * timeToExpiry)
```

or equivalently:

```
exchangeRate = exp(impliedRate * timeToExpiry)
PT price ≈ 1 / exchangeRate
```

If PT price rises, implied APY falls.

If PT price falls, implied APY rises.

## 6. YT

YT represents the yield side of the position.

YT receives pre-expiry yield and rewards.

YT value is highly sensitive to:

- expected future yield;
- reward emissions;
- points expectations;
- time to expiry;
- implied APY in the PT/SY market;
- underlying asset impairment.

A useful approximation:

```
YT value ≈ SY value - PT value
```

This is not a full pricing formula, but it explains why a PT/SY market can indirectly support YT trading.

## 7. PT/SY Market

Pendle V2 markets are PT/SY AMMs.

They are structurally closer to two-token AMMs than to Uniswap V3, but the pricing formula is custom.

Uniswap V2:

```
x * y = k
spot price comes from reserve ratio
```

Uniswap V3:

```
concentrated liquidity
ticks
range liquidity
active liquidity
```

Pendle PT/SY market:

```
two-token pool
custom implied-rate curve
time-to-expiry aware pricing
PT/SY reserve composition maps to implied APY
```

The market uses:

- total PT reserve;
- total SY reserve converted to asset units;
- time to expiry;
- rate scalar;
- rate anchor;
- last implied rate.

The key pricing flow is:

```
PT trade size
→ new PT proportion
→ logit(proportion)
→ exchangeRate
→ implied APY
→ asset/SY amount
```

## 8. Exchange Rate and Implied Rate

Pendle converts between exchange rate and implied rate.

```
exchangeRate = exp(impliedRate * timeToExpiry)
```

and:

```
impliedRate = ln(exchangeRate) / timeToExpiry
```

In code, time is normalized by `IMPLIED_RATE_TIME`.

This is why the same PT discount means very different annualized APY depending on time to expiry.

Near expiry, small price differences can imply very large annualized rates.

## 9. Rate Anchor

Pendle uses an anchor to calibrate the AMM curve around the current market state.

The simplified curve is:

```
exchangeRate = rateAnchor + logit(proportion) / rateScalar
```

where:

```
proportion = totalPt / (totalPt + totalAsset)
logit(p) = ln(p / (1 - p))
```

The anchor is chosen so that the current pool proportion maps to the exchange rate implied by `lastLnImpliedRate`.

```
rateAnchor = exp(lastLnImpliedRate * timeToExpiry)
             - logit(current proportion) / rateScalar
```

This means:

- reserve composition determines the current point on the curve;
- last implied rate anchors the curve to the market's previous yield state;
- a swap moves the market along the curve by changing PT proportion.

## 10. Swap Direction Intuition

Let:

```
netPtToAccount > 0
```

This means the user receives PT.

The pool loses PT, so PT proportion decreases.

```
PT proportion decreases
→ exchangeRate decreases
→ PT price increases
→ implied APY decreases
```

So buying PT pushes PT price up and fixed yield down.

Let:

```
netPtToAccount < 0
```

This means the user sells PT.

The pool gains PT, so PT proportion increases.

```
PT proportion increases
→ exchangeRate increases
→ PT price decreases
→ implied APY increases
```

So selling PT pushes PT price down and fixed yield up.

## 11. Main Stress Case For This Lab

The first lab scenario is:

```
1. User deposits SY when exchangeRate = 1.00
2. SY exchangeRate rises to 1.10
3. PY index follows to 1.10
4. SY exchangeRate falls to 0.95
5. PY index remains 1.10
```

Questions:

- Does PT redemption assume the floored PY index or current SY backing?
- Does YT interest accounting behave intuitively?
- Do PT/YT oracle rates reflect current impairment?
- Do LP oracle rates reflect current impairment?
- Can an external oracle consumer overvalue PT or LP collateral?
- Is the behavior a protocol-internal issue, an integration issue, or an intentional loss-allocation choice?

## 12. Security Interpretation

This lab does not assume the PY index floor is a vulnerability.

The security questions are:

- Can an attacker manipulate SY exchange rate before minting, redeeming, or trading?
- Can an external integrator overvalue PT/YT/LP by using the wrong oracle rate?
- Can a market or oracle path hide impaired SY backing?
- Can redemption or oracle accounting overstate claim value after SY impairment?

## 13. Alpha Interpretation

The same mechanics can produce market signals:

- PT implied APY versus underlying yield;
- PT discount versus maturity value;
- SY exchangeRate drawdown;
- PY index gap versus current SY exchangeRate;
- PT/SY reserve imbalance;
- maturity roll-down;
- liquidity depth;
- oracle readiness.

A large gap between floored PY index and current SY exchange rate can be interpreted as a stress signal, not just a code-path detail.
