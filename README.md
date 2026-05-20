# Pendle PT/YT Mechanism Lab

This repository studies Pendle-style yield tokenization through executable experiments.

The goal is not to claim a vulnerability in Pendle Finance. Instead, this lab uses simplified mocks, harnesses, and selected protocol mechanics to understand how value moves across:

```
yield-bearing asset
→ SY
→ PT + YT
→ PT/SY market
→ oracle rates
→ maturity / redemption
```

The core research question is:

> When the exchange rate of a yield-bearing asset decreases after previously increasing, how should losses be reflected across PT holders, YT holders, LPs, market traders, and oracle consumers?

## Motivation

Pendle-style protocols are often described using a fixed-income analogy:

- PT behaves like a principal claim.
- YT behaves like a yield strip.
- PT markets imply a fixed yield.
- LPs provide liquidity to PT/SY markets.

This analogy is useful, but incomplete.

Unlike a simple zero-coupon bond, Pendle relies on several layers of protocol accounting:

- external yield-bearing asset value;
- SY share accounting;
- PY index behavior;
- PT/YT minting and redemption;
- AMM implied-rate pricing;
- oracle conversion to asset-denominated rates.

This lab focuses on those accounting and pricing boundaries.

## Current Focus

The first experiment focuses on the **PY index floor**.

In Pendle, the PY index is monotonic: once the SY exchange rate increases, the PY index does not decrease even if the current SY exchange rate later falls.

This is an intentional design choice, not assumed to be a bug by itself.

The experiment asks:

```
SY exchangeRate: 1.00 → 1.10 → 0.95

What happens to:
- pyIndexStored
- PT redemption
- YT interest
- PT/YT oracle rates
- LP oracle rates
- external collateral valuation
```

## Why This Matters

A decreasing SY exchange rate can happen conceptually because of:

- slashing;
- depeg;
- bad adapter accounting;
- external protocol loss;
- delayed or impaired redemption;
- oracle or exchange-rate mismatch.

If downstream systems continue to treat PT, YT, or LP positions as if the underlying SY backing is unimpaired, integrations may overvalue collateral or misinterpret fixed-yield exposure.

The purpose of this lab is to make those assumptions explicit and testable.

## Planned Experiments

### 1. PY Index Floor

```
MockSY exchangeRate rises from 1.00 to 1.10.
PY index follows upward.

MockSY exchangeRate then falls from 1.10 to 0.95.
PY index remains floored at 1.10.
```

Questions:

- Does `pyIndexStored` remain monotonic?
- How does pre-expiry PT/YT redemption behave?
- How does post-expiry PT redemption behave?
- Who absorbs the loss when SY backing falls?

### 2. Oracle Consumer Overvaluation

A mock oracle consumer will read PT/YT/LP-style rates and use them for collateral valuation.

Questions:

- Which rate should an integrator use?
- What happens if an integrator ignores the SY exchange-rate impairment?
- Can a toy lending protocol become undercollateralized by using the wrong rate?

### 3. PT/SY Market Boundary Behavior

A simplified market harness will explore how implied-rate pricing responds to:

- large PT buys;
- large PT sells;
- extreme PT/SY reserve ratios;
- short time to expiry;
- low liquidity.

Questions:

- How does PT price map to implied APY?
- How does maturity compress price movement?
- Where do boundary conditions create discontinuities or DoS-style behavior?

## Repository Structure

```
src/
  mocks/
    MockSY.sol
  harness/
    PyIndexHarness.sol
    MarketMathHarness.sol

test/
  PyIndexFloor.t.sol
  OracleConsumerOvervaluation.t.sol
  MarketBoundary.t.sol

notes/
  mechanism.md
  threat-model.md
  attack-patterns.md
  limitations.md

notebooks/
  pendle_market_rates_snapshot.ipynb

data/
  raw/
  processed/
```

## Non-Goals

This repository is not:

- a full audit of Pendle Finance;
- a claim that Pendle has a live vulnerability;
- a replacement for formal verification or full protocol review;
- a trading recommendation;
- investment advice.

The goal is narrower:

> executable mechanism research for Pendle-style PT/YT/yield-tokenization systems.

## Security Lens

The lab focuses on attack patterns and integration hazards such as:

- SY exchange-rate manipulation or impairment;
- PY index asymmetry under decreasing SY exchange rate;
- PT/YT redemption accounting edge cases;
- PT/SY implied-rate boundary behavior;
- oracle consumer overvaluation;
- adapter preview/execution mismatch.

## Alpha Lens

The same mechanics can also be interpreted as market signals:

- PT implied APY;
- PT discount to maturity value;
- SY exchange-rate drawdown;
- PY index versus current SY exchange-rate gap;
- PT/SY reserve imbalance;
- liquidity depth;
- maturity roll-down;
- oracle readiness.

This repo treats protocol mechanics as both a security surface and a market-structure signal.

## Setup

```bash
forge install
forge build
```

For Python notebooks:

```bash
uv sync
uv run jupyter lab
```

## Tests

Run all tests:

```bash
forge test
```

Run a specific experiment:

```bash
forge test --match-contract PyIndexFloorTest -vvv
```

## Status

Work in progress.

Initial focus:

```
PY index floor under impaired SY exchange rate.
```

Future work:

```
PT/YT oracle behavior
LP oracle behavior
external oracle consumer overvaluation
Pendle market implied-rate boundary tests
Pendle API market-rate snapshot notebook
```

## Related Work

This lab is part of a broader series of executable DeFi mechanism studies:

- Curve StableSwap mechanism lab;
- ERC4626 inflation / donation case study;
- RWA redemption accounting case study;
- Pendle PT/YT mechanism lab.
