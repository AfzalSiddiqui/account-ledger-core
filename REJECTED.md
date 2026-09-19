# Rejected Acceptance Criteria

Four of the eight criteria are wrong. Here's why.

## Criterion 2: "E7 causes exactly one overdraft fee, on Day 2"

No. E7 is back-dated (processed Day 5, value day 2), so it changes historical balances and fees cascade:

- Day 1: 1200 - 950 = 250 (positive, no fee)
- Day 2: 250 - 620 = -370 → fee -25
- Day 3: -370 - 25 + 400 = 5 (barely positive, no fee)
- Day 4: 5 - 185 = -180 → fee -25
- Day 5: -180 - 25 = -205 → fee -25

E7 causes **three** fees (Days 2, 4, 5), totalling -75 AED. The Day 2 fee eats into Day 3's balance, which makes Day 4 go negative after the settlement, which makes Day 5 negative too.

## Criterion 6: "After E9, all balances return to pre-E7 values"

No. Ledger is append-only. E9 adds +620 but can't delete the three fee entries. Day 2 balance after E9:

250 - 620 - 25 + 620 = 225 AED (not 250)

The -25 fee persists. You'd need a fee-reversal workflow to fix this.

## Criterion 7: "Three BHD instalments must each be 3.334"

3.334 × 3 = 10.002 BHD. That's more money than we started with.

Correct split: 10000 millis / 3 = 3333 each, remainder 1 on the last. So 3.333 + 3.333 + 3.334 = 10.000.

## Criterion 8: "Remainder is discarded if accruals don't sum to capitalized total"

Can't silently lose money. If there's a rounding difference, adjust the final accrual so the sum matches exactly. Both accruals and capitalization are computed from the same final ledger state, so they agree by construction.

---

## Approaches abandoned during the build

**Incremental interest accruals** — Computed each day's interest during processing. Got 0.81 AED. Capitalization from final state gave 0.93. The mismatch happens because E7 changes Day 2's balance after Day 2's interest was already recorded. Switched to computing everything from the completed ledger.

**Remainder on first instalment** — Had BHDInstallmentAllocator putting remainder on the first instalment (3.334, 3.333, 3.333) while the processor put it on the last. Inconsistent. Standardized on last instalment.

**Per-event overdraft fees** — Assessed a fee every time any event made the balance negative. Spec says once per day per account, not per event. Changed to per-day.

**Single replay engine** — Started with only EventProcessor for everything. Testing it meant parsing stdout, which was fragile. Built EventReplay as a stateless alternative. Having two implementations agree on the same numbers caught two bugs.
