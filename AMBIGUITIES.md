# Ambiguities and Design Decisions

This document records the interpretation of requirements where the MAL event stream or acceptance criteria allow more than one implementation approach.

---

## 1. Overdraft Fee Assessment for Back-Dated Events

**Ambiguity:** E7 is booked on Day 5 but has a value day of Day 2. Should overdraft fees be assessed only for the current processing day, or should historical days affected by E7 be reassessed?

**Decision:** Fees are assessed retroactively.

When a processing-day event changes a historical balance, the processor evaluates overdraft conditions for value days from Day 1 through the current processing day.

For the supplied event stream, E7 results in three fee entries:

- `OVERDRAFT-FEE-ACC-001-DAY-2` — `-25.00 AED`
- `OVERDRAFT-FEE-ACC-001-DAY-4` — `-25.00 AED`
- `OVERDRAFT-FEE-ACC-001-DAY-5` — `-25.00 AED`

Each fee has a deterministic identifier, preventing duplicate insertion during repeated retroactive assessment.

---

## 2. Processing Day vs. Value Day

**Ambiguity:** An event can be booked on one processing day while affecting the ledger on another value day.

E7 is the key example:

- Processing day = Day 5
- Value day = Day 2

**Decision:** Events are processed in booking-day order, while ledger entries retain their value day.

Therefore:

- E7 is processed on Day 5.
- The resulting ledger entry has `valueDay = 2`.
- Historical balance queries through Day 2 include E7.
- Later historical balance queries also include the entry where appropriate.

This distinction allows back-dated events to affect historical balances without changing event processing order.

---

## 3. Interest Calculation Timing and Capitalization

**Ambiguity:** Should interest be calculated using the balances observed when each processing day originally ran, or using the completed ledger after all events have been processed?

**Decision:** Interest capitalization is calculated from the completed ledger state at Day 6.

The completed ledger includes:

- Back-dated entries
- Reversal entries
- Overdraft fee entries
- Credits and debits processed during the six-day stream

Daily interest accruals are calculated using the supported currency precision:

- AED: 2 decimal places
- BHD: 3 decimal places

### Daily Accruals

Both daily accruals and the capitalized total are computed from the completed ledger state after all events, fees, and reversals have been processed. This ensures they always agree.

For ACC-001:

| Day | Closing Balance | Daily Accrual |
|---:|---:|---:|
| 1 | 250.00 AED | 0.10 AED |
| 2 | 225.00 AED | 0.09 AED |
| 3 | 625.00 AED | 0.25 AED |
| 4 | 415.00 AED | 0.17 AED |
| 5 | 390.00 AED | 0.16 AED |
| 6 | 390.00 AED | 0.16 AED |
| **Total** | | **0.93 AED** |

For ACC-002:

| Day | Closing Balance | Daily Accrual |
|---:|---:|---:|
| 5 | 10.000 BHD | 0.004 BHD |
| 6 | 10.000 BHD | 0.004 BHD |
| **Total** | | **0.008 BHD** |

### Capitalization Entries

- `INTEREST-CAPITALIZATION-ACC-001-DAY-6` = `0.93 AED`
- `INTEREST-CAPITALIZATION-ACC-002-DAY-6` = `0.008 BHD`

The sum of rounded daily accruals equals the capitalized total for each account, satisfying the non-negotiable rule.

## 4. BHD Instalment Remainder

**Ambiguity:** BHD uses three decimal places, so BHD 10.000 is represented by 10,000 minor units. Dividing 10,000 by three does not produce three equal integer amounts.

**Decision:** Instalments are allocated in integer minor units and the remainder is assigned to the final instalment.

Calculation:

- Total = `10,000` millis
- Count = `3`
- Base instalment = `3,333` millis
- Remainder = `1` milli

Result:

- Instalment 1 = `3.333 BHD`
- Instalment 2 = `3.333 BHD`
- Instalment 3 = `3.334 BHD`

The total is exactly:

`3.333 + 3.333 + 3.334 = 10.000 BHD`

No value is created or discarded through decimal rounding.

---

## 5. Partial Settlement of an Authorization

**Ambiguity:** Auth-A reserves AED 200.00, while E5 settles AED 185.00. It must be determined whether settlement must exactly equal the authorization amount.

**Decision:** Partial settlement is valid.

For E5:

- Authorization amount = `200.00 AED`
- Settlement amount = `185.00 AED`

The settlement amount must not exceed the authorization amount.

The authorization hold is released, while the actual settlement debit is posted for AED 185.00.

Auth-A is then marked as settled.

---

## 6. Unknown Authorization Settlement

**Ambiguity:** E6 attempts to settle Auth-Z, but no authorization for Auth-Z exists.

**Decision:** The settlement is rejected.

No settlement debit is created for E6.

The processor records an error equivalent to:

`Day 4 [E6] Settlement rejected: unknown authorization Auth-Z`

The rejected settlement therefore does not change the account's ledger balance.

---

## 7. Authorization Holds and Ledger Balance

**Ambiguity:** Should an authorization hold itself change the ledger balance?

**Decision:** No.

An authorization creates a hold that affects the available balance but does not create a ledger debit.

For Auth-A:

- Ledger balance = `250.00 AED`
- Active hold = `200.00 AED`
- Available balance = `50.00 AED`

Therefore:

`Available balance = Ledger balance - Active holds`

When Auth-A is settled, the hold is released and the actual settlement debit is posted.

---

## 8. Reversal and Overdraft Fees

**Ambiguity:** E9 reverses E7. Should the overdraft fees caused by E7 also be automatically reversed?

**Decision:** No.

The ledger is append-only.

E9 creates a compensating credit entry:

`E9 = +620.00 AED, value day 2`

It does not modify or delete E7 and does not remove previously posted fee entries.

The three fee entries remain:

- Day 2 = `-25.00 AED`
- Day 4 = `-25.00 AED`
- Day 5 = `-25.00 AED`

Automatic fee rollback would require additional compensating fee-reversal entries and is outside the current ledger model.

---

## 9. Reversal Mechanics — Compensating Entry vs. Mutation

**Ambiguity:** When E9 reverses E7, should the system (a) delete or modify E7's ledger entry, (b) mark E7 as "reversed" and exclude it from balance queries, or (c) append a new compensating entry?

All three are valid approaches in different ledger systems. Option (a) is simplest but destroys audit history. Option (b) preserves history but requires every balance query to check a status flag, adding complexity. Option (c) keeps the ledger truly append-only but means both the original and the reversal coexist — the ledger grows rather than corrects.

**Decision:** Option (c) — append a compensating entry.

For E7/E9:

- E7 = `-620.00 AED`, value day 2 (remains in ledger, unmodified)
- E9 = `+620.00 AED`, value day 2 (new entry appended)

The reversal in `ReversalEngine` (line 26) negates the original amount and flips the entry type (debit becomes credit). The original entry is passed by value, never mutated.

This choice has a cost: the Day 2 overdraft fee triggered by E7 is not automatically reversed. The fee entry `OVERDRAFT-FEE-ACC-001-DAY-2` persists because the fee engine assessed it when E7 made Day 2 negative, and appending E9 does not trigger fee removal. This is the gap documented by the deliberately failing test `testDay2BalanceRestoredAfterE9Reversal`.

A production system would need a fee-reversal workflow: when a reversal restores a day's balance to positive, generate compensating fee-credit entries for any fees that no longer apply. This was cut because cascading reversal of derived entries is a non-trivial workflow — you need to determine which fees were caused by the reversed entry vs. by other events, which is ambiguous when multiple debits overlap on the same day.

---

## 10. Rejected Events — No Ledger Mutation, But What Gets Recorded?

**Ambiguity:** Three events in the stream are rejected: E6 (unknown auth settlement), E8 (insufficient available balance for Auth-B), and arguably E7's fees after E9. The question is what artifact a rejected event leaves behind.

Some systems record rejected events as zero-amount ledger entries for audit purposes. Others store them in a separate error log. The choice affects what an auditor sees when querying the ledger vs. querying the error log.

**Decision:** Rejected events create no ledger entries. They are recorded as structured errors with day, event ID, and reason.

For the supplied stream:

- E6: `Day 4 [E6] Settlement rejected: unknown authorization Auth-Z` — no debit posted, no settlement record created
- E8: Auth-B stored with `AuthorizationState.rejected` — no hold created, no debit posted

The trade-off: a regulator querying only the ledger would not see attempted-but-failed transactions. In production, the error log would need to be durable and auditable. CBUAE requires records of all attempts, not just successful postings. This is listed as a cut in the architecture document ("Durable audit trail").

---

## Summary

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Retroactive fee assessment | Back-dated events change historical balances; fees must reflect current state |
| 2 | Processing day vs. value day separation | Events process in booking order; ledger queries use value day |
| 3 | Interest from completed ledger state | Incremental computation fails when back-dated events change historical balances |
| 4 | BHD remainder on final instalment | Payment convention; exact total preserved |
| 5 | Partial settlement valid | Settlement amount may be less than authorization |
| 6 | Unknown auth settlement rejected | No ledger mutation for non-existent authorization |
| 7 | Holds do not create ledger entries | Available balance is a view, not a ledger state |
| 8 | Fees persist after reversal | Append-only ledger; fee-reversal requires explicit workflow |
| 9 | Reversal appends compensating entry | Original entry preserved for audit; cost is fee persistence |
| 10 | Rejected events produce errors, not entries | Ledger contains only successful postings; audit trail gap documented |

