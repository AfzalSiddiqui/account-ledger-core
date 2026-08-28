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

## 9. Reversal Does Not Modify the Original Entry

**Ambiguity:** A reversal could modify the original entry or replace it with a new balance.

**Decision:** The original ledger entry remains unchanged.

A reversal is represented by a new compensating entry.

For E7:

- Original E7 = `-620.00 AED`
- Reversal E9 = `+620.00 AED`

Both entries remain in the ledger.

This preserves the append-only audit trail.

---

## 10. Rejected Authorization and Available Balance

**Ambiguity:** Auth-B requests AED 90.00 on Day 5 while the available balance is insufficient.

**Decision:** Auth-B is rejected.

A rejected authorization:

- Does not create a ledger debit.
- Does not create an active hold.
- Is recorded with `AuthorizationStatus.rejected`.
- Produces an insufficient-available-balance error.

Auth-B remains rejected in the final authorization state.

---

## 11. Rejected Events and Ledger Mutation

**Ambiguity:** Should a rejected event still create a ledger entry?

**Decision:** No.

Rejected settlements and rejected authorizations do not create unintended financial ledger entries.

For the supplied stream:

- E6 is rejected because Auth-Z is unknown.
- E8 is rejected because Auth-B does not have sufficient available balance.

Both events are represented through error/status information rather than financial ledger mutations.

---

## Summary

The implementation follows these principles:

1. Events are processed in booking-day order.
2. Ledger entries retain their event value day.
3. Historical balances use value day.
4. Back-dated debits can trigger retroactive overdraft fees.
5. Overdraft fees are deterministic and idempotent.
6. Authorization holds affect available balance but not ledger balance.
7. Settlements may be partial but cannot exceed the authorization amount.
8. Unknown authorization settlements are rejected.
9. Reversals create compensating entries rather than modifying originals.
10. Overdraft fees remain after a reversal because the ledger is append-only.
11. BHD instalments use integer minor units.
12. The BHD remainder is assigned to the final instalment.
13. Interest capitalization uses the completed Day-6 ledger state.
14. Rejected events do not create unintended ledger entries.

