# Work Log

## 2026-08-28

### 09:00 — Setup and domain types

Swift package, executable target. Started with the money problem first: AED has 2 decimal places, BHD has 3. Decided on Int64 minor units immediately — I've been bitten by floating-point money bugs before and didn't want to debug that here. `Money`, `Currency`, `Account`, `LedgerEntry`, `Ledger`.

Built `Transaction` and `TransactionProcessor` for double-entry accounting (debit one account, credit another, entries must sum to zero). Also `Idempotency` store and `AccountLimit`. These ended up not being used by the event processor — the event stream works with single-sided entries, not double-entry pairs — but I kept them because the domain model underneath is still double-entry and the tests validate the invariants.

### 09:30 — Engines

`AuthorizationEngine` — this one took a bit of thinking. The spec says "available balance = ledger balance minus active holds." That means auth holds don't touch the ledger. They're tracked separately. Settlement is what actually creates the debit. Wrote this wrong the first time (had the auth creating a ledger entry), caught it during testing.

`SettlementEngine`, `ReversalEngine`, `OverdraftFeeEngine`, `InterestEngine`, `InterestCapitalization`, `BHDInstallmentAllocator`.

The overdraft fee engine went through a few iterations. Initially used `.debit` entry type, changed to `.fee` so it's distinguishable in the ledger. The big realization was deterministic IDs: `OVERDRAFT-FEE-ACC-001-DAY-2`. Without these, retroactive reassessment creates duplicate fees every time a back-dated event arrives.

### 10:30 — Event stream and processor

Encoded all 10 events in `Event.eventStream()`. Built `EventProcessor` — groups events by processing day, routes each to the right engine, then sweeps all historical days for overdraft fees.

The overdraft sweep is the trickiest part of the whole system. On each processing day, it loops from Day 1 through the current day checking every account's closing balance. This is what makes E7 cascade: E7 lands on Day 5 but has value day 2, so the sweep on Day 5 finds Day 2 is now negative, assesses a fee, and that fee ripples forward through Days 3-5.

### 11:30 — Replay engine

Built `EventReplay` as a separate stateless engine for test verification. Different approach from `EventProcessor`: takes events in, returns a result struct, no mutation, no print statements. Having two independent implementations that agree on the same numbers gives me confidence the logic is right. If they disagree, at least one is wrong.

`MALReplay.swift` holds the canonical event definitions for the replay engine.

### 12:30 — The interest bug

This one wasted time. Daily interest accruals were computed during each processing day using the balance visible at that point. Capitalization was computed from the final ledger state. The two disagreed: 0.81 AED vs 0.93 AED.

The root cause: E7 is processed on Day 5 but changes Day 2's balance retroactively. When Day 2 was originally processed, the balance was 250 AED (interest = 0.10). After E7, Day 2 balance becomes -370 (interest = 0). But the incremental approach had already recorded 0.10 for Day 2 and moved on.

Fix: compute both daily accruals and capitalization from the completed ledger state, after all events and fees. They always agree because they use the same data.

I initially resisted this — it felt like cheating to not use the "live" balances — but the spec says "rounded daily accruals must sum exactly to the capitalized total." There's no way to guarantee that with incremental computation when back-dated events can change historical balances after the fact.

### 13:30 — Tests

59 tests across 12 test files. The important ones are in `EventStreamTests` (11 tests covering E1-E10 behavior) and `MALReplayTests` (4 tests cross-validating the replay engine).

The deliberately failing test: `testDay2BalanceRestoredAfterE9Reversal`. It asserts that after E9 reverses E7, Day 2 balance returns to the pre-E7 value of 250.00. It fails because the overdraft fee (-25 AED) persists — the ledger is append-only, so reversing the debit doesn't undo its side effects. The balance is 225, not 250. I included this because it documents a real gap: in production you'd need a fee-reversal workflow.

### 14:00 — Documentation

Wrote README, NUMBERS.md, AMBIGUITIES.md, REJECTED.md.

Rejected 4 of the 8 acceptance criteria:
- Criterion 2: E7 causes 3 fees (Days 2, 4, 5), not 1
- Criterion 6: fees persist after reversal (append-only)
- Criterion 7: 3 x 3.334 = 10.002, not 10.000
- Criterion 8: can't silently discard money

### 15:30 — Bug fixes

Found 7 bugs during final review:

1. E10 was on Day 6 instead of Day 5 — caused ACC-002 to get 1 day of interest instead of 2
2. E6 amount was 500 AED instead of 180 AED — misread the spec
3. Interest mismatch (described above, 0.81 vs 0.93)
4. Auth-A stayed `.approved` after settlement — added `.settled` state
5. BHD remainder was on first instalment (3334, 3333, 3333) — code and docs disagreed, standardized on last
6. EventReplay didn't handle instalments — E10 posted as single credit instead of 3
7. The "deliberately failing" test was actually passing — it asserted the real behavior instead of the ideal behavior. Replaced it with one that genuinely fails.

### 16:15 — Final verification

```
swift build  — clean
swift test   — 59 tests, 58 passed, 1 expected failure
swift run    — correct output
```

Final balances: ACC-001 = 390.93 AED, ACC-002 = 10.008 BHD.
