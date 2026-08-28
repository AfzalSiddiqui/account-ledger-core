import XCTest
@testable import account_ledger_core

final class AccountingTests: XCTestCase {

    func testOverdraftFeeIsAssessedOncePerDay() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        var ledger = Ledger()

        ledger.append(
            LedgerEntry(
                id: "E7",
                accountID: account.id,
                amount: Money(
                    currency: .AED,
                    minorUnits: -37_000
                ),
                type: .debit,
                valueDay: 2,
                sourceEventID: "E7"
            )
        )

        let engine = OverdraftFeeEngine()

        XCTAssertTrue(
            engine.assess(
                for: account,
                throughDay: 2,
                ledger: &ledger
            )
        )

        XCTAssertFalse(
            engine.assess(
                for: account,
                throughDay: 2,
                ledger: &ledger
            )
        )

        XCTAssertEqual(
            ledger.balance(
                for: account,
                throughDay: 2
            ).minorUnits,
            -39_500
        )
    }

    func testNoOverdraftFeeForPositiveBalance() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        var ledger = Ledger()

        ledger.append(
            LedgerEntry(
                id: "E1",
                accountID: account.id,
                amount: Money(
                    currency: .AED,
                    minorUnits: 120_000
                ),
                type: .credit,
                valueDay: 1,
                sourceEventID: "E1"
            )
        )

        let engine = OverdraftFeeEngine()

        XCTAssertFalse(
            engine.assess(
                for: account,
                throughDay: 1,
                ledger: &ledger
            )
        )
    }

    func testDailyAEDInterestIsRoundedToTwoDecimals() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        var ledger = Ledger()

        ledger.append(
            LedgerEntry(
                id: "E1",
                accountID: account.id,
                amount: Money(
                    currency: .AED,
                    minorUnits: 100_000
                ),
                type: .credit,
                valueDay: 1,
                sourceEventID: "E1"
            )
        )

        let engine = InterestEngine()

        XCTAssertEqual(
            engine.dailyAccrual(
                for: account,
                throughDay: 1,
                ledger: ledger
            ),
            Money(
                currency: .AED,
                minorUnits: 40
            )
        )
    }

    func testDailyBHDInterestIsRoundedToThreeDecimals() {
        let account = Account(
            id: "ACC-002",
            currency: .BHD
        )

        var ledger = Ledger()

        ledger.append(
            LedgerEntry(
                id: "E1",
                accountID: account.id,
                amount: Money(
                    currency: .BHD,
                    minorUnits: 10_000
                ),
                type: .credit,
                valueDay: 1,
                sourceEventID: "E1"
            )
        )

        let engine = InterestEngine()

        XCTAssertEqual(
            engine.dailyAccrual(
                for: account,
                throughDay: 1,
                ledger: ledger
            ),
            Money(
                currency: .BHD,
                minorUnits: 4
            )
        )
    }

    func testInterestIsZeroForNegativeBalance() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        var ledger = Ledger()

        ledger.append(
            LedgerEntry(
                id: "E1",
                accountID: account.id,
                amount: Money(
                    currency: .AED,
                    minorUnits: -100_000
                ),
                type: .debit,
                valueDay: 1,
                sourceEventID: "E1"
            )
        )

        XCTAssertEqual(
            InterestEngine().dailyAccrual(
                for: account,
                throughDay: 1,
                ledger: ledger
            ),
            .zero(.AED)
        )
    }

    func testCapitalizationUsesSumOfRoundedDailyAccruals() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        var ledger = Ledger()

        ledger.append(
            LedgerEntry(
                id: "E1",
                accountID: account.id,
                amount: Money(
                    currency: .AED,
                    minorUnits: 120_000
                ),
                type: .credit,
                valueDay: 1,
                sourceEventID: "E1"
            )
        )

        let engine = InterestEngine()

        let daily = engine.dailyAccruals(
            for: account,
            throughDay: 6,
            ledger: ledger
        )

        let total = daily.reduce(
            Money.zero(.AED)
        ) {
            $0.adding($1)
        }

        XCTAssertEqual(total.minorUnits, 288)
    }

    func testDay6CapitalizationCreatesSingleCredit() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        var ledger = Ledger()

        ledger.append(
            LedgerEntry(
                id: "E1",
                accountID: account.id,
                amount: Money(
                    currency: .AED,
                    minorUnits: 120_000
                ),
                type: .credit,
                valueDay: 1,
                sourceEventID: "E1"
            )
        )

        let capitalization = InterestCapitalization()

        let result = capitalization.capitalize(
            for: account,
            on: 6,
            ledger: &ledger
        )

        XCTAssertEqual(
            result,
            Money(
                currency: .AED,
                minorUnits: 288
            )
        )

        let interestEntries = ledger.entries.filter {
            $0.sourceEventID ==
            "INTEREST-CAPITALIZATION-ACC-001-DAY-6"
        }

        XCTAssertEqual(interestEntries.count, 1)
        XCTAssertEqual(interestEntries[0].amount.minorUnits, 288)
    }

    func testCapitalizationIsIdempotent() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        var ledger = Ledger()

        ledger.append(
            LedgerEntry(
                id: "E1",
                accountID: account.id,
                amount: Money(
                    currency: .AED,
                    minorUnits: 120_000
                ),
                type: .credit,
                valueDay: 1,
                sourceEventID: "E1"
            )
        )

        let capitalization = InterestCapitalization()

        let first = capitalization.capitalize(
            for: account,
            on: 6,
            ledger: &ledger
        )

        let second = capitalization.capitalize(
            for: account,
            on: 6,
            ledger: &ledger
        )

        XCTAssertEqual(first.minorUnits, 288)
        XCTAssertEqual(second.minorUnits, 0)
    }
}
