import XCTest
@testable import account_ledger_core

final class ReversalTests: XCTestCase {

    func testReversalCreatesCompensatingEntry() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        let original = LedgerEntry(
            id: "SET-001",
            accountID: account.id,
            amount: Money(currency: .AED, minorUnits: -18500),
            type: .debit,
            valueDay: 4
        )

        let engine = ReversalEngine()

        let reversal = engine.reverse(
            id: "REV-001",
            originalEntry: original,
            account: account
        )

        let entry = engine.ledgerEntry(
            for: reversal,
            valueDay: 5
        )

        XCTAssertEqual(reversal.state, .reversed)
        XCTAssertEqual(reversal.originalEntryID, "SET-001")
        XCTAssertEqual(entry?.amount.minorUnits, 18500)
        XCTAssertEqual(entry?.type, .credit)
        XCTAssertEqual(entry?.sourceEventID, "SET-001")
    }

    func testReversalDoesNotModifyOriginalEntry() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        let original = LedgerEntry(
            id: "SET-001",
            accountID: account.id,
            amount: Money(currency: .AED, minorUnits: -18500),
            type: .debit,
            valueDay: 4
        )

        let engine = ReversalEngine()

        _ = engine.reverse(
            id: "REV-001",
            originalEntry: original,
            account: account
        )

        XCTAssertEqual(original.amount.minorUnits, -18500)
        XCTAssertEqual(original.type, .debit)
        XCTAssertEqual(original.id, "SET-001")
    }

    func testReversalRejectsEntryFromAnotherAccount() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        let original = LedgerEntry(
            id: "SET-002",
            accountID: "ACC-999",
            amount: Money(currency: .AED, minorUnits: -5000),
            type: .debit,
            valueDay: 4
        )

        let engine = ReversalEngine()

        let reversal = engine.reverse(
            id: "REV-002",
            originalEntry: original,
            account: account
        )

        XCTAssertEqual(reversal.state, .rejected)
        XCTAssertNil(
            engine.ledgerEntry(
                for: reversal,
                valueDay: 5
            )
        )
    }
}
