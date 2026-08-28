# Work Log

## 2026-08-28

### 09:00 — Project setup

- Initialized Swift package with `swift package init --type executable`.
- Created `Package.swift` with executable target `account-ledger-core` and test target.
- Established basic domain types: `Currency`, `Money`, `Account`, `LedgerEntry`, `Ledger`.

### 09:30 — Core domain model

- `Money`: integer minor-units representation, AED (scale 2), BHD (scale 3).
- `Ledger`: append-only entry store with `balance(for:throughDay:)` query.
- `Account`: id, currency, zero opening balance.
- `LedgerEntry`: id, accountID, amount, type, valueDay, sourceEventID.
- `Transaction`, `TransactionState`, `TransactionProcessor`: double-entry transaction support.
- `LedgerInvariant`, `LedgerReconciliation`: balance validation helpers.
- `Idempotency`: tracks processed transaction IDs to prevent duplicates.
- `AccountLimit`: maximum debit limit validation.

### 10:00 — Authorization and settlement engines

- `AuthorizationEngine`: evaluates hold against available balance (ledger balance minus active holds).
- `SettlementEngine`: full and partial settlement of authorized amounts.
- `ReversalEngine`: creates compensating entries (never modifies originals).
- `OverdraftFeeEngine`: assesses AED 25.00 fee when closing balance is negative, deterministic entry IDs.
- `InterestEngine`: 0.04% daily rate on positive balances, integer arithmetic with half-up rounding.
- `InterestCapitalization`: posts single credit entry at end of Day 6.
- `BHDInstallmentAllocator`: splits BHD amount into N instalments with remainder handling.

### 10:30 — Event model and stream (Step 1)

- Created `Event.swift` with `EventType` enum and `Event` struct.
- Implemented `Event.eventStream()` returning all 10 events.
- Events include: `authorizationID`, `reversesEventID`, `instalments`, `settlementAmount`.

### 11:00 — Settlement engine update (Step 2)

- Added `settle(id:authorization:account:settlementAmount:)` overload for partial settlement.
- E5 settles Auth-A: authorization 200.00 AED, settlement 185.00 AED.

### 11:30 — Event processor (Step 3)

- Created `EventProcessor.swift` as central orchestrator.
- Groups events by processing day, processes in order.
- Handles: credit (with instalment splitting), debit, authorization, settlement, reversal.
- Retroactive overdraft fee assessment across all historical value days.
- Daily and final summary reports.

### 12:00 — EventReplay engine

- Created `EventReplay.swift` with `ReplayEvent`, `AuthorizationRecord`, `DailyReplayReport`, `ReplayResult`.
- Separate replay engine for test-driven verification.
- `MALReplay.swift`: canonical event definitions for the MAL specification.

### 12:30 — Overdraft fee engine fix

- Changed entry type from `.debit` to `.fee`.
- Deterministic IDs: `OVERDRAFT-FEE-{accountID}-DAY-{day}`.

### 13:00 — EventReplay retroactive fee fix

- Updated `EventReplay` to assess overdraft fees for all days from Day 1 through current processing day.
- Previously assessed only current day — missed cascading fees from E7.

### 13:30 — Test suite (Steps 4–5)

- Updated `AccountLedgerCore.swift` main entry point.
- Created `EventStreamTests.swift` with 11 test cases covering the full event stream.
- Created/maintained unit tests: `MoneyTests`, `LedgerTests`, `AccountingTests`, `SettlementTests`, `ReversalTests`, `TransactionTests`, `TransactionStateTests`, `IdempotencyTests`, `LedgerHardeningTests`, `AccountLimitTests`, `MALReplayTests`.

### 14:00 — Documentation (Step 6)

- Created `README.md`, `NUMBERS.md`, `AMBIGUITIES.md`, `REJECTED.md`, `WORKLOG.md`.

### 15:30 — Bug fixes (Step 5b)

Seven bugs identified and corrected:

1. **E10 processing day and value day** (`Event.swift`):
   - Was: `day=6, valueDay=6`
   - Fixed: `day=5, valueDay=5` per specification

2. **E6 amount** (`Event.swift`):
   - Was: `50,000 minor units (AED 500.00)`
   - Fixed: `18,000 minor units (AED 180.00)` per specification

3. **Interest daily accruals vs. capitalization mismatch** (`EventProcessor.swift`):
   - Was: daily accruals computed incrementally during processing (0.81 AED), capitalization from final state (0.93 AED)
   - Fixed: both computed from final ledger state after all events and fees
   - Daily accruals now sum exactly to capitalized total: 0.93 AED

4. **Auth-A not marked settled** (`Authorization.swift`, `EventProcessor.swift`):
   - Was: only `.approved` and `.rejected` states; Auth-A showed "approved" after settlement
   - Fixed: added `.settled` state; Auth-A updated after E5

5. **BHDInstallmentAllocator remainder assignment** (`BHDInstallmentAllocator.swift`):
   - Was: remainder on first instalment (3334, 3333, 3333)
   - Fixed: remainder on final instalment (3333, 3333, 3334)

6. **EventReplay missing instalment support** (`EventReplay.swift`, `MALReplay.swift`):
   - Was: E10 posted as single credit
   - Fixed: added `instalments` field and splitting logic

7. **Deliberately failing test was passing** (`EventStreamTests.swift`):
   - Was: `testFeesPersistAfterE9Reversal` asserted actual behavior (passed)
   - Fixed: replaced with `testDay2BalanceRestoredAfterE9Reversal` (genuinely fails)

### 16:00 — Documentation updates

- Updated all `.md` files to reflect bug fixes.
- `NUMBERS.md`: added "why that value" justifications, corrected ACC-002 interest (0.008 BHD), final balance (10.008 BHD).
- `REJECTED.md`: added "Approaches Abandoned Mid-Build" section.
- `AMBIGUITIES.md`: corrected interest accrual tables to match final-state computation.
- `WORKLOG.md`: added timestamps.

### 16:15 — Final verification

- `swift build` — successful
- `swift test` — 59 tests, 58 passed, 1 deliberate failure
- Final balances: ACC-001 = 390.93 AED, ACC-002 = 10.008 BHD
- Auth-A: settled, Auth-B: rejected
- Daily interest: ACC-001 = 0.93 AED (6 days), ACC-002 = 0.008 BHD (2 days)
- Overdraft fees: 3 (Days 2, 4, 5)
- Instalment split: 3.333 + 3.333 + 3.334 = 10.000 BHD
