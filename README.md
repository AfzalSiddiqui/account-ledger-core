# account-ledger-core

An in-memory account ledger core with event stream replay. Swift. No web layer, no persistence, no UI, no database.

Two accounts:

- **ACC-001** — AED, opening balance 0.00
- **ACC-002** — BHD, opening balance 0.000

Six-day window (Day 1 through Day 6), ten events (E1–E10).

## Build

```bash
swift build
```

Requires Swift 6.2+.

## Run

```bash
swift run
```

Prints a 6-day report followed by a final summary.

### Reading the output

The output has two sections:

**1. Daily Reports (Day 1–6):**

Each day block shows:

- **Closing balance** per account — the ledger balance using all entries with `value_date ≤ that day`, as known at that processing day.
- **Active holds** and **Available balance** — shown only when authorization holds exist. Available = ledger balance minus active holds.
- **Fees assessed** — overdraft fees posted with that value day.
- **Errors** — rejected settlements, rejected authorizations.

**2. Final Summary (After Day 6):**

- **Final balance** per account — closing balance including interest capitalization.
- **Authorization States** — each authorization's final state (approved, settled, or rejected).
- **Ledger Entries** — the complete append-only ledger, one line per entry, showing ID, account, amount, type, and value day.
- **All Errors** — every error across all processing days.
- **Daily Interest Accruals** — per-account daily accrual amounts computed from the final ledger state, plus the capitalized total.

### Key values in the output

| Item | Value |
|------|-------|
| ACC-001 final balance | 390.93 AED |
| ACC-002 final balance | 10.008 BHD |
| Auth-A | settled |
| Auth-B | rejected |
| E6 (Auth-Z) | rejected — unknown authorization |
| Overdraft fees | 3 total: Days 2, 4, 5 |
| ACC-001 interest | 0.93 AED (capitalized Day 6) |
| ACC-002 interest | 0.008 BHD (capitalized Day 6) |

## Test

```bash
swift test
```

59 tests total. 58 pass. One deliberately failing test:

**`testDay2BalanceRestoredAfterE9Reversal`** — asserts that after E9 reverses E7, the Day 2 balance returns to the pre-E7 value of 250.00 AED. It fails because the overdraft fee (AED -25.00) persists in the append-only ledger, leaving the balance at 225.00 AED. This reveals that reversing a transaction does not undo its side effects; a separate fee-reversal workflow would be needed in production.

## Documentation

- [NUMBERS.md](NUMBERS.md) — every constant, why that value and not half it
- [AMBIGUITIES.md](AMBIGUITIES.md) — every ambiguity found and how it was resolved
- [REJECTED.md](REJECTED.md) — acceptance criteria refused with reasons, plus abandoned approaches
- [WORKLOG.md](WORKLOG.md) — timestamped implementation log
