# Numbers and Constants

Every constant chosen, why that value and not half it.

---

## Overdraft Fee

- **Amount:** AED 25.00 (2,500 fils)
- **Frequency:** At most once per account per value day
- **Trigger:** Negative closing ledger balance for the applicable value day
- **Entry type:** `LedgerEntryType.fee`
- **Entry ID:** `OVERDRAFT-FEE-{accountID}-DAY-{day}`

**Why 25.00 and not 12.50?** The specification states "Overdraft fee: AED 25.00". This is a non-negotiable rule — the value is prescribed, not chosen.

**Why once per day and not per-event?** The specification says "assessed once per day per account". Per-event assessment would be a different (and harsher) model. Per-day caps the penalty and is the stated rule.

**Why deterministic IDs?** A deterministic ID like `OVERDRAFT-FEE-ACC-001-DAY-2` makes the fee idempotent. When back-dated events force retroactive reassessment, the engine can loop over all historical days without risking duplicate fee entries. Without deterministic IDs, the engine would need a separate tracking structure and could still produce duplicates across processing passes.

For the supplied event stream, E7 causes three overdraft fees:

- Day 2: `-25.00 AED`
- Day 4: `-25.00 AED`
- Day 5: `-25.00 AED`

---

## Interest Rate

- **Daily rate:** `0.0004` (0.04% per day)
- **Representation:** `4 / 10,000` in integer arithmetic
- **Applies to:** Positive closing ledger balances only
- **Rounding:** Banker's rounding (half-up) to currency precision

**Why 0.0004 and not 0.0002?** The specification states "0.04% per day". This is prescribed.

**Why 4/10,000 and not floating-point 0.0004?** Integer arithmetic avoids IEEE 754 rounding errors. The numerator (4) and denominator (10,000) produce exact results when combined with minor-unit balances. Using `Double(balance) * 0.0004` would introduce representational noise that could cause the daily accruals to not sum exactly to the capitalized total.

**Why round each daily accrual?** The specification says "amounts stored and rounded to their own precision." Each daily accrual is a monetary value and must respect the currency's decimal places. Accumulating unrounded accruals and rounding only at capitalization would violate this rule and could produce a capitalized total that differs from the sum of reported daily values.

**Why half-up rounding?** `(numerator + denominator/2) / denominator` implements symmetric half-up rounding. This is the standard rounding convention for financial calculations. Truncation would systematically understate interest; ceiling would overstate it.

---

## Currency Scales

| Currency | Decimal Places | Minor Unit | Example |
|---|---:|---|---|
| AED | 2 | fils | `1,200.00 AED = 120,000 fils` |
| BHD | 3 | fils | `10.000 BHD = 10,000 fils` |

**Why 2 for AED?** ISO 4217 specifies AED as a 2-decimal currency.

**Why 3 for BHD?** ISO 4217 specifies BHD as a 3-decimal currency. The specification also states "BHD is 3."

**Why minor units (integer) and not decimal?** Integer arithmetic eliminates floating-point representation errors. `AED 0.10` is exactly `10 fils`; there is no IEEE 754 approximation involved. Every arithmetic operation (addition, subtraction, fee/interest calculation) remains exact until the final display formatting.

---

## Event Stream

| Event | Processing Day | Type | Account | Amount | Value Day | Notes |
|---|---:|---|---|---:|---:|---|
| E1 | 1 | Credit | ACC-001 | 1,200.00 AED | 1 | Opening credit |
| E2 | 1 | Debit | ACC-001 | 950.00 AED | 1 | Debit |
| E3 | 2 | Authorization | ACC-001 | 200.00 AED | 2 | Auth-A |
| E4 | 3 | Credit | ACC-001 | 400.00 AED | 3 | Credit |
| E5 | 4 | Settlement | ACC-001 | 185.00 AED | 4 | Partial settlement of Auth-A |
| E6 | 4 | Settlement | ACC-001 | 180.00 AED | 4 | Auth-Z; rejected — unknown |
| E7 | 5 | Debit | ACC-001 | 620.00 AED | 2 | Back-dated debit |
| E8 | 5 | Authorization | ACC-001 | 90.00 AED | 5 | Auth-B; rejected |
| E9 | 6 | Reversal | ACC-001 | 620.00 AED | 2 | Reversal of E7 |
| E10 | 5 | Credit | ACC-002 | 10.000 BHD | 5 | Three instalments |

All amounts and days are prescribed by the specification.

---

## BHD Instalment Allocation

E10 credits BHD 10.000 to ACC-002 in three instalments.

- **Total:** 10,000 millis
- **Count:** 3
- **Base instalment:** `10,000 / 3 = 3,333` millis
- **Remainder:** `10,000 % 3 = 1` milli

**Why assign remainder to the final instalment?** Integer division produces a 1-milli remainder. This must go somewhere. Assigning it to the final instalment is a common convention in payment systems — the last instalment absorbs rounding. Assigning it to the first would work equally well arithmetically, but last-instalment assignment is more conventional and avoids front-loading.

| Instalment | Amount |
|---|---:|
| E10-instalment-1 | 3.333 BHD |
| E10-instalment-2 | 3.333 BHD |
| E10-instalment-3 | 3.334 BHD |
| **Total** | **10.000 BHD** |

---

## Daily Interest Accruals

Interest is computed from the completed ledger state (after all events, fees, and reversals). Both daily accruals and the capitalized total use the same calculation pass, guaranteeing they agree.

### ACC-001

| Day | Closing Balance | Calculation | Daily Accrual |
|---:|---:|---|---:|
| 1 | 250.00 AED | 25000 × 4 / 10000 = 10 fils | 0.10 AED |
| 2 | 225.00 AED | 22500 × 4 / 10000 = 9 fils | 0.09 AED |
| 3 | 625.00 AED | 62500 × 4 / 10000 = 25 fils | 0.25 AED |
| 4 | 415.00 AED | 41500 × 4 / 10000 = 17 fils | 0.17 AED |
| 5 | 390.00 AED | 39000 × 4 / 10000 = 16 fils | 0.16 AED |
| 6 | 390.00 AED | 39000 × 4 / 10000 = 16 fils | 0.16 AED |
| **Total** | | | **0.93 AED** |

**Why is Day 2 balance 225.00 and not 250.00?** Because interest uses the completed ledger state. E7 (debit -620, value day 2) and E9 (reversal +620, value day 2) are both included, along with the Day 2 overdraft fee (-25). Net: `250 - 620 - 25 + 620 = 225`.

### ACC-002

| Day | Closing Balance | Calculation | Daily Accrual |
|---:|---:|---|---:|
| 5 | 10.000 BHD | 10000 × 4 / 10000 = 4 millis | 0.004 BHD |
| 6 | 10.000 BHD | 10000 × 4 / 10000 = 4 millis | 0.004 BHD |
| **Total** | | | **0.008 BHD** |

---

## Final Capitalization Entries

At the end of Day 6:

- `INTEREST-CAPITALIZATION-ACC-001-DAY-6` — `0.93 AED`
- `INTEREST-CAPITALIZATION-ACC-002-DAY-6` — `0.008 BHD`

Sum of rounded daily accruals equals the capitalized total for each account.

---

## Final Reported Balances

| Account | Balance |
|---|---:|
| ACC-001 | 390.93 AED |
| ACC-002 | 10.008 BHD |

**ACC-001 breakdown:** `1200 - 950 - 620 - 25 + 400 - 185 - 25 - 25 + 620 + 0.93 = 390.93`

**ACC-002 breakdown:** `3.333 + 3.333 + 3.334 + 0.008 = 10.008`
