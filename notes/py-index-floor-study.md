# PY Index Floor Study

## Summary

This note studies a Pendle-style PY index floor under a decreasing SY exchange-rate scenario.

The experiment does not claim that the PY index floor is a vulnerability. The monotonic index is a reasonable accounting design for yield-tokenization systems because it avoids retroactively decreasing accrued yield accounting.

The important observation is different:

> When current SY exchange rate falls below the stored PY index, accounting value and current recoverable backing can diverge.

This divergence is a stress state. It matters for PT holders, YT holders, LPs, market traders, and especially external oracle consumers that may treat PT or LP positions as risk-free collateral.

## Experiment Setup

The lab uses two minimal contracts:

- `MockSY`: a simplified Standardized Yield token with a manually controlled `exchangeRate`.
- `PyIndexHarness`: a minimal harness modeling the Pendle-style rule:

```
pyIndexCurrent = max(current SY exchangeRate, pyIndexStored)
```

The tested path is:

```
SY exchangeRate starts at 1.00
SY exchangeRate rises to 1.10
PY index updates to 1.10
SY exchangeRate falls to 0.95
PY index remains floored at 1.10
```

## Test Results

The test suite confirms:

```bash
forge test --match-contract PyIndexFloorTest -vvv
```

Result:

```
4 passed; 0 failed; 0 skipped
```

Covered tests:

- `test_initialPyIndexEqualsInitialSyExchangeRate`
- `test_pyIndexIncreasesWhenSyExchangeRateIncreases`
- `test_pyIndexDoesNotDecreaseWhenSyExchangeRateFalls`
- `test_accountingIndexCanDivergeFromRecoverableBacking`

## Key Observation

After the stress path:

```
current SY exchangeRate = 0.95
pyIndexStored           = 1.10
stress gap              = 0.15
```

For `100 SY`:

```
recoverable backing at current SY exchangeRate = 95 asset units
PY accounting amount using floored index       = 110 accounting units
```

This shows that the PY index can remain above the current recoverable backing when the underlying SY exchange rate decreases.

## Interpretation

This is not automatically a protocol bug.

A monotonic PY index can be a valid design choice because it preserves accounting consistency after yield has accrued. If the index could decrease, it would create difficult questions around already accrued interest, YT accounting, transfers, reward claims, and redemption timing.

The security-relevant question is:

> Which downstream path treats the accounting index as recoverable value?

If a path correctly accounts for impaired backing, the stress gap is simply a loss-allocation state.

If an external integration treats PT, YT, or LP positions as fully backed by the stored accounting index, it may overvalue collateral.

## PT Interpretation

PT is principal-like, but not risk-free.

A better model is:

```
PT = principal-like claim on risky SY backing
```

If SY backing remains sound, PT behaves similarly to a fixed-income principal claim.

If SY backing is impaired, PT holders can lose value.

Therefore, PT should not be treated as a risk-free zero-coupon bond without considering:

- SY adapter risk;
- underlying asset depeg or slashing;
- redemption impairment;
- oracle/exchange-rate correctness;
- market liquidity;
- maturity handling.

## Loss Allocation

When SY exchange rate falls because of real impairment, the system is not zero-sum inside Pendle-style contracts.

The total recoverable value has decreased.

Possible affected parties include:

- PT holders;
- YT holders;
- LPs;
- traders who bought before impairment was priced in;
- external lending protocols or vaults using unsafe oracle assumptions.

Potential beneficiaries are usually outside the immediate PT/YT accounting system:

- an external attacker who caused the underlying loss;
- informed traders who sold or hedged before the impairment;
- attackers who exploit an external protocol that overvalues impaired PT or LP collateral.

## Security Implication

The most important attack pattern is not simply:

```
SY exchangeRate falls
```

The important attack pattern is:

```
SY exchangeRate falls
→ accounting index remains higher than current backing
→ external consumer treats accounting value as recoverable value
→ PT/LP collateral is overvalued
→ attacker extracts value from the external consumer
```

This shifts the focus from “PY index floor is a bug” to:

> unsafe integration under PY index / SY exchange-rate divergence.

## Alpha Implication

The gap between stored PY index and current SY exchange rate can be interpreted as a stress signal:

```
stress gap = pyIndexStored - current SY exchangeRate
```

A nonzero stress gap may indicate:

- impaired underlying backing;
- depeg or slashing risk;
- adapter accounting stress;
- hidden risk premium in PT implied APY;
- potential mispricing between PT, YT, LP, and external collateral markets.

## Current Limitations

This first experiment is intentionally simplified.

It does not yet model:

- full Pendle `PendleYieldToken` behavior;
- full PT/YT mint and redeem flows;
- market swaps;
- LP accounting;
- Pendle oracle libraries;
- external lending integration;
- real SY adapters.

The next step is to add a toy oracle consumer or lending protocol to test how unsafe collateral valuation can transfer losses to an external system.

## Next Experiments

Planned follow-up tests:

1. `OracleConsumerOvervaluation.t.sol`
   - A toy lending protocol accepts PT-like collateral.
   - It uses an unsafe accounting-index-based valuation.
   - The test shows overvaluation after SY impairment.

2. `MarketBoundary.t.sol`
   - A simplified PT/SY market harness maps PT trade direction to implied APY.
   - Tests large buys, large sells, and near-expiry behavior.

3. Real Pendle math harness
   - Import selected Pendle core math libraries.
   - Compare simplified formulas against Pendle market math.


## Oracle Consumer Overvaluation Experiment

The second experiment adds `UnsafeOracleConsumer`, a toy external integration that values SY-backed collateral using the floored PY accounting index instead of the current SY exchange rate.

The setup follows the same stress path:

```
SY exchangeRate: 1.00 → 1.10 → 0.95
PY index:        1.00 → 1.10 → 1.10
```

For `100 SY`:

```
unsafe value using PY index              = 110
recoverable value using current SY rate  = 95
overvaluation                            = 15
```

This experiment demonstrates the main integration hazard:

> A monotonic PY index can be correct protocol accounting, while still being unsafe as a proxy for current recoverable collateral value under impaired SY backing.

The attack pattern is external:

```
SY backing becomes impaired
→ PY index remains floored for accounting consistency
→ external consumer uses PY-index-based valuation
→ collateral is overvalued
→ losses can be transferred to the external consumer
```

This is why integrators should distinguish between:

- accounting index;
- current SY exchange rate;
- recoverable backing;
- oracle rate intended for the specific asset and use case.


## Mock Lending Over-Borrow Experiment

The third experiment turns collateral overvaluation into a concrete lending failure mode.

A toy lending protocol uses `UnsafeOracleConsumer` to value SY-denominated collateral by the floored PY index. The protocol then allows borrowing at 80% LTV.

After the stress path:

```
SY exchangeRate = 0.95
PY index        = 1.10
```

For `100 SY` collateral:

```
unsafe collateral value = 110
safe collateral value   = 95
```

At 80% LTV:

```
unsafe borrow limit = 88
safe borrow limit   = 76
excess borrow       = 12
```

The test demonstrates that a borrower can borrow up to the unsafe limit and become undercollateralized under current recoverable-value accounting.

This models an unsafe external integration pattern, not necessarily a Pendle core issue.