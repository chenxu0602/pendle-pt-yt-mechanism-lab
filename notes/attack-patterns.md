# Pendle-Style Attack Patterns

This note maps Pendle-style PT/YT mechanics into concrete attack patterns, integration hazards, and testable scenarios.

The goal is not to claim that Pendle Finance has these vulnerabilities. The goal is to identify where yield-tokenization systems can fail if accounting, exchange rates, oracle reads, or integrations are implemented incorrectly.

## 1. SY Exchange-Rate Manipulation or Impairment

SY is the adapter layer between an external yield-bearing asset and the PT/YT system.

If the SY exchange rate is wrong, manipulable, stale, or impaired, downstream PT/YT/LP valuation can become wrong.

Potential causes:

- external protocol loss;
- LST/LRT slashing;
- depeg;
- ERC4626 share-price donation or inflation;
- LP-token virtual-price manipulation;
- stale or incorrectly scaled oracle;
- delayed withdrawal or liquidity shortage;
- adapter preview/execution mismatch.

Core failure mode:

```
SY exchangeRate is treated as reliable,
but the current recoverable backing is lower than reported or assumed.
```

Attack or stress path:

```
attacker or external event changes underlying exchange-rate source
→ SY exchangeRate / recoverable value diverges
→ PT/YT minting, redemption, oracle rate, or LP valuation uses the wrong value
→ value is misallocated or external consumer overvalues collateral
```

Test direction:

- create a mock SY whose exchange rate can rise and fall;
- compare current exchange rate with stored PY index;
- observe PT/YT redemption and oracle-style valuation under impairment.

## 2. PY Index / SY Exchange-Rate Divergence

The PY index is monotonic.

A simplified model:

```
pyIndexCurrent = max(current SY exchangeRate, stored PY index)
```

This is not assumed to be a vulnerability. It is an accounting design that avoids retroactively decreasing the PT/YT conversion index.

However, it creates a stress state when current SY backing falls below the stored PY index.

Stress case:

```
SY exchangeRate: 1.00 → 1.10 → 0.95
PY index:        1.00 → 1.10 → 1.10
```

The key question is not whether the PY index should decrease. The key question is:

```
When current SY backing is below the stored accounting index,
who absorbs the loss?
```

Possible affected parties:

- PT holders;
- YT holders;
- LPs;
- market traders;
- treasury;
- external oracle consumers;
- lending protocols using PT/LP as collateral.

Important distinction:

```
pyIndexStored is an accounting index.
current SY exchangeRate is closer to current backing or recoverable value.
```

A mismatch between the two is a stress signal, not necessarily a protocol bug.

Test direction:

- show that PY index remains floored after exchange-rate decrease;
- measure how PT/YT redemption behaves;
- measure how oracle-style valuation behaves;
- show how an external consumer can be wrong if it treats accounting value as risk-free recoverable value.

## 3. Oracle Consumer Overvaluation

Many serious Pendle-style risks may appear outside the core protocol.

If an external lending protocol, vault, or strategy uses PT/YT/LP rates incorrectly, it can overvalue collateral.

Unsafe integration patterns:

- using spot-like rates without TWAP checks;
- using duration zero or insufficient observation history;
- skipping `getOracleState` or equivalent readiness checks;
- using a raw PT/YT/LP rate without accounting for impaired SY backing;
- assuming PT is a risk-free zero-coupon bond;
- assuming LP token value is always backed by unimpaired SY;
- ignoring expiry boundary behavior.

Attack path:

```
attacker acquires or creates overvalued PT/LP position
→ external protocol reads inflated or incomplete valuation
→ attacker borrows against overvalued collateral
→ SY impairment or market correction reveals insufficient backing
→ external protocol becomes undercollateralized
```

This is an external integration issue unless the core protocol itself exposes a misleading rate as safe for that use case.

Test direction:

- build a toy lending protocol;
- allow PT or LP collateral;
- let it read a simplified oracle rate;
- show that using the wrong rate can overvalue collateral under SY impairment.

## 4. PT Is Principal-Like, Not Risk-Free

A common mental model is:

```
PT = zero-coupon bond
```

This is useful but incomplete.

A more accurate model is:

```
PT = principal-like claim on risky SY backing
```

If SY backing remains sound, PT behaves like a fixed-yield principal claim and tends toward maturity redemption value.

If SY backing is impaired, PT holders can lose value.

Failure mode:

```
integrator treats PT as risk-free principal
but PT is actually exposed to SY adapter and underlying asset risk
```

Consequences:

- PT collateral may be overvalued;
- PT implied APY may be misread as pure fixed yield instead of risk premium;
- maturity redemption assumptions may fail under impaired backing.

Test direction:

- compare PT behavior under healthy SY and impaired SY;
- show that PT is senior-like but not risk-free;
- map where loss appears in redemption or valuation.

## 5. YT as Junior Yield Exposure

YT represents the yield side of the position.

In stress scenarios, YT is usually more junior than PT.

YT can lose value because of:

- lower future yield;
- reward decline;
- points repricing;
- underlying depeg;
- SY impairment;
- time decay.

Failure mode:

```
YT buyer treats expected yield or points as stable,
but underlying yield source deteriorates before expiry.
```

Security relevance is usually indirect. YT mispricing is often a market risk rather than a protocol vulnerability.

However, it becomes a security issue if:

- reward accounting can be manipulated;
- interest accounting can be double-counted;
- claimed rewards are misallocated;
- oracle consumers use YT valuation unsafely;
- maturity logic leaves stale or claimable value in the wrong place.

Test direction:

- model yield accrual before and after exchange-rate impairment;
- check whether YT receives, loses, or misreports value in each state.

## 6. LP Valuation Under Impaired Backing

Pendle LPs hold exposure to both PT and SY through the market.

A simplified intuition:

```
LP ≈ PT exposure + SY exposure + fee economics
```

If SY backing is impaired, LP value can also be impaired.

Potential failure modes:

- LP oracle rate does not reflect impaired SY backing;
- market reserve composition hides loss allocation;
- direct SY/PT donations create raw-balance versus accounted-reserve mismatch;
- LP collateral valuation ignores reserve imbalance;
- oracle read during reentrancy or insufficient TWAP overvalues LP.

Attack path:

```
SY backing falls
→ LP valuation remains too high
→ attacker uses LP token as collateral
→ borrows too much
→ lending protocol absorbs the loss
```

Test direction:

- build simplified LP valuation under healthy and impaired SY;
- compare raw reserve accounting versus recoverable asset value;
- show how LP collateral can be overvalued by an unsafe external consumer.

## 7. PT/SY Market Boundary Manipulation

Pendle markets price PT through an implied-rate curve rather than a constant-product curve.

Simplified pricing flow:

```
PT trade size
→ new PT proportion
→ logit(proportion)
→ exchangeRate
→ implied APY
→ asset/SY amount
```

Boundary-sensitive variables:

- time to expiry;
- PT/SY reserve ratio;
- liquidity depth;
- maximum market proportion;
- exchangeRate lower bound;
- fee and reserve-fee rounding;
- PY index conversion between SY and asset.

Potential attack or stress cases:

- near-expiry small price moves create very large annualized implied APY moves;
- extreme PT/SY proportions cause discontinuities or reverts;
- low-liquidity markets are easier to manipulate;
- spot-like oracle consumers can be manipulated with large swaps;
- rounding can matter for very small trades.

Test direction:

- simulate large PT buys and sells;
- test short time-to-expiry;
- test extreme reserve ratios;
- map PT price movement to implied APY movement.

## 8. Adapter Preview / Execution Mismatch

SY adapters expose preview and execution functions.

A common invariant is:

```
previewDeposit should not overstate actual SY minted.
previewRedeem should not overstate actual tokenOut received.
```

This must be interpreted in the same state and without external state changes.

Failure modes:

- fee-on-transfer asset causes actual received amount to be lower than nominal amount;
- rebasing token changes balance during execution;
- ERC4626 share price changes between preview and deposit;
- external vault donation changes exchange rate;
- paused or illiquid external market makes redeem fail after preview succeeds;
- reward claiming changes balances in unexpected ways.

Attack path:

```
attacker manipulates external adapter state
→ preview reports favorable amount
→ protocol mints/redeems/accounting uses wrong value
→ attacker extracts value or causes shortfall
```

Test direction:

- create mock adapter with preview/execution divergence;
- show how unsafe downstream accounting can be broken;
- compare safe design using actual balance delta.

## 9. Maturity and Expiry Boundary Issues

PT/YT behavior changes at expiry.

Before expiry:

```
PT + YT are needed to redeem SY.
```

After expiry:

```
PT alone can redeem principal-side value.
YT no longer has principal claim.
```

Potential failure modes:

- off-by-one expiry boundary;
- stale interest/reward accounting around expiry;
- post-expiry treasury allocation double-counts or undercounts yield;
- oracle rates behave unexpectedly at or near expiry;
- markets fail or revert close to expiry;
- integrators do not handle expired PT/LP correctly.

Test direction:

- test exactly before expiry;
- test at expiry;
- test after expiry;
- compare PT redemption and YT residual value.

## 10. Flash-Loan-Sized State Transitions

Pendle does not need to expose a native flash-loan function to be flash-loan-sensitive.

External flash liquidity can interact atomically with:

- SY adapters;
- PT/YT minting;
- PT/SY market swaps;
- oracle observations;
- router callbacks;
- external lending integrations.

Direct Pendle AMM manipulation is usually not profitable by itself because the attacker pays slippage and fees.

The dangerous case is when a manipulated state is consumed elsewhere.

Examples:

```
large flash-loan-funded PT/SY swap
→ manipulated spot-like rate
→ external protocol reads unsafe price
→ attacker borrows against overvalued collateral
```

or:

```
flash-loan manipulation of external pool
→ SY adapter exchangeRate changes
→ PT/YT/LP valuation becomes wrong
→ external consumer accepts bad valuation
```

Test direction:

- identify spot-like reads;
- identify unsafe oracle consumers;
- model whether a same-transaction state change can affect valuation.

## 11. What This Lab Will Test First

The first experiment focuses on SY impairment after prior yield accrual.

Scenario:

```
1. SY exchangeRate starts at 1.00.
2. SY exchangeRate rises to 1.10.
3. PY index follows to 1.10.
4. SY exchangeRate falls to 0.95.
5. PY index remains at 1.10.
```

The experiment will observe:

- PY index monotonicity;
- PT redemption behavior;
- YT accounting behavior;
- oracle-style valuation;
- LP-style valuation;
- external consumer overvaluation.

Primary research question:

```
When current SY backing falls below the stored PY index,
does the system and its integrations correctly distinguish accounting value from recoverable value?
```

Expected output:

- Foundry test showing the PY index floor behavior;
- simplified loss-allocation table;
- toy oracle-consumer example;
- notes on what is protocol-internal behavior versus unsafe external integration.