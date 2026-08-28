# Work Log

## 2026-08-28

### Event Model and Stream (Step 1)

- Created `Event.swift` with `EventType` enum and `Event` struct.
- Implemented `Event.eventStream()` returning all 10 events from the MAL specification.
- Events include support for:
  - `authorizationID`
  - `reversesEventID`
  - `instalments`
  - `settlementAmount`

### Settlement Engine Update (Step 2)

- Added `settle(id:authorization:account:settlementAmount:)` overload to `SettlementEngine`.
- Supports partial settlement for E5:
  - Authorization amount: AED 200.00
  - Settlement amount: AED 185.00
- Settlement amount cannot exceed the authorization amount.

### Event Processor (Step 3)

- Created `EventProcessor.swift` as the central event-stream orchestrator.
- Processes events grouped by processing day.
- Handles:
  - Credit
  - Debit
  - Authorization
  - Settlement
  - Reversal
- Supports instalment allocation.
- Instalment remainder is assigned to the final instalment.
- Implements retroactive overdraft fee assessment for historical value days.
- Tracks daily interest accruals.
- Capitalizes interest at the end of Day 6.
- Produces daily and final summary reports.

### Overdraft Fee Engine Fix

- Changed `OverdraftFeeEngine` entry type from `.debit` to `.fee`.
- Fee entries now use the dedicated `LedgerEntryType.fee` case.
- Fee entries use deterministic identifiers:
  - `OVERDRAFT-FEE-{accountID}-DAY-{day}`

### EventReplay Retroactive Fee Fix

- Updated `EventReplay` to assess overdraft fees retroactively for all applicable days from Day 1 through the current processing day.
- Previously, fees were assessed only for the current processing day.
- This supports cascading overdraft behavior when a back-dated debit such as E7 affects historical balances.
- The fee engine prevents duplicate fee entries for the same account and day.

### MALReplayTests Corrections

- Corrected contradictory balance assertions.
- Corrected Day 3 report expectations so they represent processing-time snapshots rather than final-state balances.
- Corrected Day 6 expectations to account for the three cascading overdraft fees.
- Added assertions verifying:
  - Total overdraft fee count = 3
  - Fee days = `{2, 4, 5}`

### Main Entry Point (Step 4)

- Updated `AccountLedgerCore.swift` to construct the supplied event stream and run the event processor.
- The executable prints:
  - Daily balances
  - Active holds
  - Available balances where applicable
  - Fee assessments
  - Authorization states
  - Replay errors
  - Daily interest accruals
  - Final balances
  - Final ledger entries

### Event Stream Tests (Step 5)

- Created `EventStreamTests.swift` with 11 test cases.
- These tests cover:
  - Day 2 closing balance
  - Three cascading overdraft fees
  - Auth-A settlement
  - Auth-Z rejection
  - Auth-B rejection
  - Authorization hold behavior
  - Fee persistence after E9 reversal
  - BHD instalment distribution
  - Interest accrual totals
  - Interest capitalization

`EventStreamTests.swift` is one test file within the complete package test suite. Its 11 tests should not be confused with the total number of tests executed by `swift test`.

### Test Status

The latest `swift test` run completed successfully:

- **Test suites:** all passed
- **Total tests:** 59
- **Failures:** 0
- **Unexpected failures:** 0

Latest result:

`Executed 59 tests, with 0 failures (0 unexpected)`

There is currently **no deliberately failing test** in the package.

The earlier test named `testFeesAreAutomaticallyReversedAfterE9` was used to document the append-only fee behavior during development. The current test suite reflects the implemented behavior: E9 reverses the original E7 transaction through a compensating entry, while previously posted overdraft fees remain in the append-only ledger.

### Documentation (Step 6)

Created and maintained the following documentation:

- `README.md`
  - Build instructions
  - Run instructions
  - Test instructions
  - Documentation index
  - Exact event-stream summary

- `NUMBERS.md`
  - Currency scales
  - Overdraft fee amount
  - Interest rate
  - Rounding rules
  - Exact event-stream values
  - BHD instalment allocation

- `AMBIGUITIES.md`
  - Documented ambiguous requirements
  - Recorded implementation decisions
  - Explained processing day vs. value day
  - Explained authorization holds
  - Explained partial settlement
  - Explained reversal and fee behavior
  - Explained interest calculation timing

- `REJECTED.md`
  - Documents the four rejected acceptance criteria
  - Includes supporting calculations
  - Explains cascading overdraft fees
  - Explains append-only reversal behavior
  - Explains exact BHD instalment allocation
  - Explains interest rounding requirements

- `WORKLOG.md`
  - Records implementation steps and current verification status

### Current Verification

The implementation has been verified with the latest package test run:

- `swift build` — successful
- `swift test` — successful
- **59 tests executed**
- **59 tests passed**
- **0 failures**
- **0 unexpected failures**

The executable event-stream output also confirms the expected six-day replay behavior across ACC-001 (AED) and ACC-002 (BHD), including the three cascading overdraft fees, authorization outcomes, E7 reversal, BHD instalment allocation, and Day 6 interest capitalization.
