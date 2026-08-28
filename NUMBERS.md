# Numbers and Constants

This document records the monetary constants, precision rules, interest rate, and event-stream values used by the implementation.

## Overdraft Fee

- **Amount:** AED 25.00
- **Minor units:** 2,500 fils
- **Frequency:** At most once per account per value day
- **Trigger:** Negative closing balance for the applicable value day
- **Entry type:** `LedgerEntryType.fee`
- **Entry ID:** `OVERDRAFT-FEE-{accountID}-DAY-{day}`

For the supplied event stream, E7 causes three overdraft fees:

- Day 2: `-25.00 AED`
- Day 4: `-25.00 AED`
- Day 5: `-25.00 AED`

## Interest

- **Daily rate:** `0.0004`
- **Equivalent:** `4 / 10,000`
- **Applies to:** Positive balances
- **AED precision:** 2 decimal places
- **BHD precision:** 3 decimal places
- **Rounding:** Daily accruals are rounded to the currency precision

The Day-6 capitalization is calculated from the completed ledger state.

## Currency Scales

| Currency | Decimal Places | Minor Unit | Example |
|---|---:|---|---|
| AED | 2 | fils | `1,200.00 AED = 120,000 fils` |
| BHD | 3 | fils | `10.000 BHD = 10,000 fils` |

## Event Stream

The implementation processes events in booking/processing-day order. Each ledger entry retains the event's value day.

| Event | Processing Day | Type | Account | Amount | Value Day | Notes |
|---|---:|---|---|---:|---:|---|
| E1 | 1 | Credit | ACC-001 | 1,200.00 AED | 1 | Opening credit |
| E2 | 1 | Debit | ACC-001 | 950.00 AED | 1 | Debit |
| E3 | 2 | Authorization | ACC-001 | 200.00 AED | 2 | Auth-A |
| E4 | 3 | Credit | ACC-001 | 400.00 AED | 3 | Credit |
| E5 | 4 | Settlement | ACC-001 | 185.00 AED | 4 | Partial settlement of Auth-A |
| E6 | 4 | Settlement | ACC-001 | 180.00 AED | 4 | Auth-Z; rejected because authorization is unknown |
| E7 | 5 | Debit | ACC-001 | 620.00 AED | 2 | Back-dated debit |
| E8 | 5 | Authorization | ACC-001 | 90.00 AED | 5 | Auth-B; rejected due to insufficient available balance |
| E9 | 6 | Reversal | ACC-001 | 620.00 AED | 2 | Reversal of E7 |
| E10 | 6 | Credit | ACC-002 | 10.000 BHD | 6 | Three instalments |

## BHD Instalment Allocation

E10 credits BHD 10.000 to ACC-002 and splits the amount into three instalments.

BHD uses three decimal places, so the amount is represented as 10,000 minor units (millis).

- **Total:** 10,000 millis
- **Count:** 3
- **Base instalment:** `10,000 / 3 = 3,333` millis
- **Remainder:** `10,000 % 3 = 1` milli

The remainder is assigned to the final instalment:

| Instalment | Amount |
|---|---:|
| E10-instalment-1 | 3.333 BHD |
| E10-instalment-2 | 3.333 BHD |
| E10-instalment-3 | 3.334 BHD |
| **Total** | **10.000 BHD** |

## Final Capitalization Entries

At the end of Day 6, the implementation creates:

- `INTEREST-CAPITALIZATION-ACC-001-DAY-6` — `0.93 AED`
- `INTEREST-CAPITALIZATION-ACC-002-DAY-6` — `0.004 BHD`

## Final Reported Balances

After Day 6:

- **ACC-001:** `390.93 AED`
- **ACC-002:** `10.004 BHD`

