# account-ledger-core

An in-memory account ledger core with event stream replay.

## Build

```bash
swift build
```

## Run

```bash
swift run
```

Prints a 6-day report showing daily closing balances, fee assessments, authorization states, and errors for a 10-event stream across two accounts (AED and BHD).

## Test

```bash
swift test
```

All tests pass except one deliberately failing test (`testFeesAreAutomaticallyReversedAfterE9`) which documents the append-only ledger limitation: overdraft fees persist after their triggering event is reversed.

## Documentation

- [REJECTED.md](REJECTED.md) — Four acceptance criteria rejected with reasoning
- [AMBIGUITIES.md](AMBIGUITIES.md) — Design decisions for ambiguous requirements
- [NUMBERS.md](NUMBERS.md) — Constants, rates, and currency scales
- [WORKLOG.md](WORKLOG.md) — Timestamped implementation log
