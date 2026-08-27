import XCTest
@testable import account_ledger_core

final class LedgerTests: XCTestCase {

    func testLedgerEntryPreservesOriginalEventInformation() {
        let entry = LedgerEntry(
            id: "E1",
            accountID: "ACC-001",
            amount: Money(currency: .AED, minorUnits: 120000),
            type: .credit,
            valueDay: 1,
            sourceEventID: "E1"
        )

        XCTAssertEqual(entry.id, "E1")
        XCTAssertEqual(entry.accountID, "ACC-001")
        XCTAssertEqual(entry.amount.minorUnits, 120000)
        XCTAssertEqual(entry.type, .credit)
        XCTAssertEqual(entry.valueDay, 1)
        XCTAssertEqual(entry.sourceEventID, "E1")
    }

    func testAccountStartsWithZeroBalance() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        XCTAssertEqual(account.openingBalance.minorUnits, 0)
        XCTAssertEqual(account.currency, .AED)
    }

    func testBalanceUsesValueDate() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        var ledger = Ledger()

        ledger.append(
            LedgerEntry(
                id: "E1",
                accountID: "ACC-001",
                amount: Money(currency: .AED, minorUnits: 120000),
                type: .credit,
                valueDay: 1
            )
        )

        ledger.append(
            LedgerEntry(
                id: "E2",
                accountID: "ACC-001",
                amount: Money(currency: .AED, minorUnits: -95000),
                type: .debit,
                valueDay: 1
            )
        )

        ledger.append(
            LedgerEntry(
                id: "E3",
                accountID: "ACC-001",
                amount: Money(currency: .AED, minorUnits: 40000),
                type: .credit,
                valueDay: 3
            )
        )

        XCTAssertEqual(
            ledger.balance(for: account, throughDay: 1).minorUnits,
            25000
        )

        XCTAssertEqual(
            ledger.balance(for: account, throughDay: 2).minorUnits,
            25000
        )

        XCTAssertEqual(
            ledger.balance(for: account, throughDay: 3).minorUnits,
            65000
        )
    }

    func testLedgerIsAppendOnly() {
        var ledger = Ledger()

        let entry = LedgerEntry(
            id: "E1",
            accountID: "ACC-001",
            amount: Money(currency: .AED, minorUnits: 10000),
            type: .credit,
            valueDay: 1
        )

        ledger.append(entry)

        XCTAssertEqual(ledger.entries.count, 1)
        XCTAssertEqual(ledger.entries[0], entry)
    }
}

extension LedgerTests {

    func testAuthorizationUsesAvailableBalanceAfterHold() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        var ledger = Ledger()

        ledger.append(
            LedgerEntry(
                id: "E1",
                accountID: "ACC-001",
                amount: Money(currency: .AED, minorUnits: 120000),
                type: .credit,
                valueDay: 1
            )
        )

        ledger.append(
            LedgerEntry(
                id: "E2",
                accountID: "ACC-001",
                amount: Money(currency: .AED, minorUnits: -95000),
                type: .debit,
                valueDay: 1
            )
        )

        let result = AuthorizationEngine().authorize(
            id: "Auth-A",
            account: account,
            ledger: ledger,
            holdAmount: Money(currency: .AED, minorUnits: 20000),
            activeHolds: [],
            throughDay: 2
        )

        XCTAssertEqual(result.state, .approved)
    }

    func testAuthorizationIsRejectedWhenHoldMakesAvailableBalanceNegative() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        var ledger = Ledger()

        ledger.append(
            LedgerEntry(
                id: "E1",
                accountID: "ACC-001",
                amount: Money(currency: .AED, minorUnits: 25000),
                type: .credit,
                valueDay: 1
            )
        )

        let result = AuthorizationEngine().authorize(
            id: "Auth-B",
            account: account,
            ledger: ledger,
            holdAmount: Money(currency: .AED, minorUnits: 30000),
            activeHolds: [],
            throughDay: 2
        )

        XCTAssertEqual(result.state, .rejected)
    }
}
