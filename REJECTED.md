# Rejected Acceptance Criteria

Four of the eight acceptance criteria are rejected because they conflict with the ledger rules and the supplied event stream.

---

## Criterion 2: "E7 causes exactly one overdraft fee, on Day 2"

**REJECTED**

E7 is a debit of AED 620.00 with value day 2, processed on Day 5. Because the debit is back-dated, it changes historical ledger balances and can cause overdraft fees to cascade into later days.

The balances below show the effect of E7 and the applicable overdraft fees:

| Day | Calculation | Closing Balance | Fee Assessed? |
|-----|-------------|----------------:|---------------|
| 1 | 1200 - 950 | 250.00 AED | No |
| 2 | 250 - 620 | -370.00 AED | Yes: -25.00 AED |
| 3 | -370 - 25 + 400 | 5.00 AED | No |
| 4 | 5 - 185 | -180.00 AED | Yes: -25.00 AED |
| 5 | -180 - 25 | -205.00 AED | Yes: -25.00 AED |

The Day 3 calculation includes the Day 2 overdraft fee:

- Day 2 balance after E7 = -370.00 AED
- Day 2 fee = -25.00 AED
- Day 3 credit = +400.00 AED
- Day 3 closing balance = 5.00 AED

Therefore, E7 causes **three overdraft fees**, on Days **2, 4, and 5**, rather than exactly one fee on Day 2.

The cascade is:

1. E7 makes the Day 2 balance negative, so a Day 2 fee of AED 25.00 is assessed.
2. The Day 2 fee reduces the Day 3 balance to AED 5.00.
3. The Day 4 settlement of AED 185.00 makes the Day 4 balance negative, causing a second fee.
4. The Day 4 fee keeps the Day 5 balance negative, causing a third fee.

The resulting fee entries are:

- `OVERDRAFT-FEE-ACC-001-DAY-2` = `-25.00 AED`
- `OVERDRAFT-FEE-ACC-001-DAY-4` = `-25.00 AED`
- `OVERDRAFT-FEE-ACC-001-DAY-5` = `-25.00 AED`

**Total overdraft fees caused by E7: `-75.00 AED`.**

---

## Criterion 6: "After E9, all balances and fees return to pre-E7 values"

**REJECTED**

The ledger is append-only. E9 reverses E7 by adding a compensating credit entry of AED 620.00 with value day 2.

The original E7 entry remains in the ledger, and the three overdraft fee entries remain as independent ledger entries:

- `OVERDRAFT-FEE-ACC-001-DAY-2` = `-25.00 AED`
- `OVERDRAFT-FEE-ACC-001-DAY-4` = `-25.00 AED`
- `OVERDRAFT-FEE-ACC-001-DAY-5` = `-25.00 AED`

After E9, the Day 2 balance is:

`250 - 620 - 25 + 620 = 225.00 AED`

Therefore, it does **not** return to the pre-E7 value of AED 250.00.

The fees persist because they are real append-only ledger entries. Automatically removing them would require additional compensating fee-reversal entries or another explicit fee-reversal workflow.

---

## Criterion 7: "Three BHD instalments must each be 3.334"

**REJECTED**

Three instalments of BHD 3.334 would total:

`3.334 × 3 = 10.002 BHD`

This exceeds the original BHD 10.000 amount by BHD 0.002.

The correct allocation uses integer minor units (millis):

- Total = `10,000` millis
- Count = `3`
- Base instalment = `10,000 / 3 = 3,333` millis
- Remainder = `10,000 % 3 = 1` milli

Therefore:

- Instalment 1 = `3.333 BHD`
- Instalment 2 = `3.333 BHD`
- Instalment 3 = `3.334 BHD`

Total:

`3.333 + 3.333 + 3.334 = 10.000 BHD`

The remainder is assigned to the final instalment so that the allocation is exact.

---

## Criterion 8: "Remainder is discarded if accruals don't sum to capitalized total"

**REJECTED**

Discarding a remainder would violate the requirement that daily interest accruals must sum exactly to the capitalized amount.

Daily accruals are calculated and rounded to the supported currency precision:

- AED: 2 decimal places
- BHD: 3 decimal places

The capitalized interest must represent the exact sum of the applicable rounded daily accruals.

If an implementation produces a rounding difference, it must be resolved explicitly rather than silently discarded. A valid approach is to apply the adjustment to the final applicable accrual so that:

`sum(daily accruals) == capitalized total`

No monetary remainder should be silently lost.

---

## Summary

The following four acceptance criteria are rejected:

| Criterion | Reason |
|-----------|--------|
| 2 | E7 causes three cascading overdraft fees, not one |
| 6 | Append-only reversal does not automatically remove previously posted fees |
| 7 | Three BHD 3.334 instalments exceed the original BHD 10.000 amount |
| 8 | Interest rounding remainders must not be silently discarded |

These rejections are based on the event-stream behavior and the append-only ledger model implemented by the project.
