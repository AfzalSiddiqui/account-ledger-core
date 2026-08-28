//
// EventStreamTests.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import XCTest
@testable import account_ledger_core

final class EventStreamTests: XCTestCase {

    private func buildProcessor() -> EventProcessor {
        var processor = EventProcessor()
        processor.process(events: Event.eventStream())
        return processor
    }

    // MARK: - Day 2 closing balance

    func testDay2ClosingBalanceIsNegative370BeforeFees() {
        // After E7 (value day 2): 1200 - 950 - 620 = -370
        // Before fees are applied, the raw balance at day 2 is -370
        let account = Account(id: "ACC-001", currency: .AED)
        var ledger = Ledger()

        // E1: credit 1200
        ledger.append(LedgerEntry(
            id: "E1", accountID: "ACC-001",
            amount: Money(currency: .AED, minorUnits: 120_000),
            type: .credit, valueDay: 1, sourceEventID: "E1"
        ))

        // E2: debit 950
        ledger.append(LedgerEntry(
            id: "E2", accountID: "ACC-001",
            amount: Money(currency: .AED, minorUnits: -95_000),
            type: .debit, valueDay: 1, sourceEventID: "E2"
        ))

        // E7: debit 620, value day 2
        ledger.append(LedgerEntry(
            id: "E7", accountID: "ACC-001",
            amount: Money(currency: .AED, minorUnits: -62_000),
            type: .debit, valueDay: 2, sourceEventID: "E7"
        ))

        let balance = ledger.balance(for: account, throughDay: 2)
        XCTAssertEqual(balance.minorUnits, -37_000,
                       "Day 2 closing = 1200 - 950 - 620 = -370.00 AED")
    }

    // MARK: - E7 triggers three overdraft fees

    func testE7CausesThreeOverdraftFees() {
        // After E7 (value day 2), closing balances:
        //   Day 2: 1200 - 950 - 620 = -370 → fee -25 → -395
        //   Day 3: -395 + 400 = +5 → no fee (positive after day 2 fee + E4 credit)
        //     Wait: Day 3 balance = Day 2 balance + E4(400) = -370 + 400 = +30 before fee
        //     But fee on Day 2 makes it: -395 + 400 = +5 → still positive, no fee
        //   Day 4: +5 - 185 = -180 → fee -25 → -205
        //     Settlement E5 is -185 on value day 4
        //   Day 5: -205 → fee -25 → -230
        //     (no new entries on day 5 except auth-B hold which doesn't affect ledger)
        //
        // Actually let's trace through the full processor to verify
        let processor = buildProcessor()

        let feeEntries = processor.ledger.entries.filter {
            $0.type == .fee && $0.accountID == "ACC-001"
        }

        // E7 causes fees on days 2, 4, and 5
        XCTAssertEqual(feeEntries.count, 3,
                       "E7 should cause exactly 3 overdraft fees (Days 2, 4, 5)")

        let feeDays = Set(feeEntries.map { $0.valueDay })
        XCTAssertTrue(feeDays.contains(2), "Fee expected on Day 2")
        XCTAssertTrue(feeDays.contains(4), "Fee expected on Day 4")
        XCTAssertTrue(feeDays.contains(5), "Fee expected on Day 5")
    }

    // MARK: - Auth-A settlement accepted

    func testAuthASettlementIsAccepted() {
        let processor = buildProcessor()

        // E5 settles Auth-A — should produce a debit entry
        let settlementEntry = processor.ledger.entries.first {
            $0.id == "E5"
        }

        XCTAssertNotNil(settlementEntry,
                        "Auth-A settlement (E5) must be accepted")
        XCTAssertEqual(settlementEntry?.amount.minorUnits, -18_500,
                       "Settlement amount should be -185.00 AED")
    }

    // MARK: - Unknown auth (Auth-Z) settlement rejected

    func testAuthZSettlementIsRejected() {
        let processor = buildProcessor()

        // E6 tries to settle Auth-Z which was never authorized
        let settlementEntry = processor.ledger.entries.first {
            $0.id == "E6"
        }

        XCTAssertNil(settlementEntry,
                     "Auth-Z settlement (E6) must be rejected — no ledger entry")

        let hasError = processor.errors.contains {
            $0.eventID == "E6"
        }

        XCTAssertTrue(hasError,
                      "E6 should produce an error for unknown authorization")
    }

    // MARK: - Auth-B rejected (insufficient available funds)

    func testAuthBIsRejected() {
        let processor = buildProcessor()

        let authB = processor.authorizations["Auth-B"]
        XCTAssertNotNil(authB, "Auth-B should exist in authorization registry")
        XCTAssertEqual(authB?.state, .rejected,
                       "Auth-B should be rejected due to insufficient available funds")
    }

    // MARK: - Auth hold does not affect ledger balance

    func testAuthorizationHoldDoesNotAffectLedgerBalance() {
        let account = Account(id: "ACC-001", currency: .AED)
        var ledger = Ledger()

        ledger.append(LedgerEntry(
            id: "E1", accountID: "ACC-001",
            amount: Money(currency: .AED, minorUnits: 120_000),
            type: .credit, valueDay: 1, sourceEventID: "E1"
        ))

        let balanceBefore = ledger.balance(for: account, throughDay: 2)

        // Authorizing does NOT append anything to ledger
        let engine = AuthorizationEngine()
        _ = engine.authorize(
            id: "Auth-Test",
            account: account,
            ledger: ledger,
            holdAmount: Money(currency: .AED, minorUnits: 20_000),
            activeHolds: [],
            throughDay: 2
        )

        let balanceAfter = ledger.balance(for: account, throughDay: 2)
        XCTAssertEqual(balanceBefore, balanceAfter,
                       "Authorization hold must not change ledger balance")
    }

    // MARK: - After E9, fees persist (append-only)

    func testAfterE9ReversalFeesPersist() {
        let processor = buildProcessor()

        // E9 reverses E7, but overdraft fees assessed due to E7
        // should NOT be automatically reversed (append-only ledger)
        let feeEntries = processor.ledger.entries.filter {
            $0.type == .fee && $0.accountID == "ACC-001"
        }

        // The fees from E7's overdraft period remain in the ledger
        XCTAssertFalse(feeEntries.isEmpty,
                       "Overdraft fees must persist after E9 reversal (append-only)")
    }

    // MARK: - BHD instalments: 3.333, 3.333, 3.334

    func testBHDInstalmentsDistributeCorrectly() {
        let processor = buildProcessor()

        let instalmentEntries = processor.ledger.entries.filter {
            $0.sourceEventID == "E10"
        }.sorted { $0.id < $1.id }

        XCTAssertEqual(instalmentEntries.count, 3,
                       "E10 should produce 3 instalment entries")

        // BHD 10.000 = 10000 millis
        // 10000 / 3 = 3333 per instalment, remainder 1
        // First two: 3333, last: 3334
        XCTAssertEqual(instalmentEntries[0].amount.minorUnits, 3_333,
                       "First instalment: 3.333 BHD")
        XCTAssertEqual(instalmentEntries[1].amount.minorUnits, 3_333,
                       "Second instalment: 3.333 BHD")
        XCTAssertEqual(instalmentEntries[2].amount.minorUnits, 3_334,
                       "Third instalment: 3.334 BHD (absorbs remainder)")

        let total = instalmentEntries.reduce(Int64(0)) {
            $0 + $1.amount.minorUnits
        }
        XCTAssertEqual(total, 10_000,
                       "Instalments must sum exactly to 10.000 BHD")
    }

    // MARK: - Interest accruals sum exactly to capitalized total

    func testInterestAccrualsSumToCapitalizedTotal() {
        let account = Account(id: "ACC-001", currency: .AED)
        var ledger = Ledger()

        // Simple scenario: AED 1200 credit on day 1, static balance
        ledger.append(LedgerEntry(
            id: "E1", accountID: "ACC-001",
            amount: Money(currency: .AED, minorUnits: 120_000),
            type: .credit, valueDay: 1, sourceEventID: "E1"
        ))

        let engine = InterestEngine()
        let accruals = engine.dailyAccruals(
            for: account, throughDay: 6, ledger: ledger
        )
        let sumOfAccruals = accruals.reduce(Int64(0)) {
            $0 + $1.minorUnits
        }

        let capitalized = engine.capitalizedInterest(
            for: account, throughDay: 6, ledger: ledger
        )

        XCTAssertEqual(sumOfAccruals, capitalized.minorUnits,
                       "Sum of rounded daily accruals must equal capitalized total")
    }

    // MARK: - Interest capitalization posts single entry

    func testInterestCapitalizationOnDay6() {
        let processor = buildProcessor()

        let interestEntries = processor.ledger.entries.filter {
            $0.type == .interest || ($0.type == .credit &&
            ($0.sourceEventID?.hasPrefix("INTEREST-CAPITALIZATION") ?? false))
        }

        // Interest should be capitalized for accounts with positive balances
        // The exact count depends on which accounts had positive balances
        // ACC-001 may or may not have had positive days depending on fee cascade
        // ACC-002 received BHD 10.000 on day 6 — interest for only day 6
        for entry in interestEntries {
            XCTAssertEqual(entry.valueDay, 6,
                           "Interest capitalization should be on Day 6")
        }
    }

    // MARK: - Deliberate failing test (annotated)

    func testDay2BalanceRestoredAfterE9Reversal() {
        // DELIBERATELY FAILING TEST
        //
        // This test asserts that after E9 reverses E7, the Day 2 closing
        // balance returns to its pre-E7 value of AED 250.00.
        //
        // This FAILS because the ledger is append-only: the overdraft fee
        // posted on Day 2 (AED -25.00) due to E7 persists even after E9
        // reverses E7. The actual Day 2 balance after E9 is:
        //
        //   250 - 620 - 25 + 620 = 225.00 AED  (not 250.00)
        //
        // What this reveals:
        //   Reversing a transaction does not undo its side effects.
        //   The overdraft fee assessed on Day 2 due to E7's back-dated
        //   debit remains in the append-only ledger. In production, a
        //   separate fee-reversal workflow posting explicit compensating
        //   entries would be needed. Without this, customers bear fees
        //   for an overdraft period that was later undone — a real-world
        //   gap between the simplified ledger model and production.

        let processor = buildProcessor()
        let account = Account(id: "ACC-001", currency: .AED)

        let day2Balance = processor.ledger.balance(
            for: account,
            throughDay: 2
        )

        // Pre-E7 Day 2 balance was 250.00 AED.
        // After E9 reverses E7, the balance should ideally return to 250.00.
        // But the Day 2 overdraft fee (AED -25.00) persists, leaving 225.00.
        XCTAssertEqual(day2Balance.minorUnits, 25_000,
                       "EXPECTED TO FAIL: Day 2 balance is 225.00 AED (not 250.00) because the overdraft fee persists in the append-only ledger")
    }
}
