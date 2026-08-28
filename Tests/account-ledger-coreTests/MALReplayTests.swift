import XCTest
@testable import account_ledger_core

final class MALReplayTests: XCTestCase {

    func testE10BHDThreeWayAllocationIsExact() {
        let total = Money(
            currency: .BHD,
            minorUnits: 10_000
        )

        let installments = BHDInstallmentAllocator().allocate(
            total: total,
            count: 3
        )

        XCTAssertEqual(
            installments.map(\.minorUnits),
            [3_334, 3_333, 3_333]
        )

        XCTAssertEqual(
            installments.reduce(Int64(0)) {
                $0 + $1.minorUnits
            },
            10_000
        )
    }

    func testE1ThroughE10Replay() {
        let replay = EventReplay(
            accounts: MALReplay.accounts
        )

        let result = replay.replay(
            events: MALReplay.events,
            throughDay: 6
        )

        XCTAssertEqual(result.reports.count, 6)

        let account = MALReplay.accounts[0]

        // Day 1:
        // 1200 - 950 = 250 AED.
        XCTAssertEqual(
            result.reports[0].balances[account.id]?.minorUnits,
            25_000
        )

        // E7 is booked on Day 5, despite valueDay = 2.
        // Therefore it is not present during the original
        // Day-2 replay pass.
        XCTAssertEqual(
            result.reports[1].balances[account.id]?.minorUnits,
            25_000
        )

        // After E7 is replayed, its value date is Day 2.
        // Historical Day-2 balance becomes:
        //
        // 250 - 620 = -370 AED.
        XCTAssertEqual(
            result.ledger.balance(
                for: account,
                throughDay: 2
            ).minorUnits,
            -37_000
        )

        // Exactly one historical Day-2 overdraft fee.
        let day2Fees = result.ledger.entries.filter {
            $0.accountID == account.id &&
            $0.valueDay == 2 &&
            $0.sourceEventID?.hasPrefix("OVERDRAFT-FEE-") == true
        }

        XCTAssertEqual(day2Fees.count, 1)

        XCTAssertEqual(
            day2Fees.first?.amount.minorUnits,
            -2_500
        )

        // Day 3:
        //
        // 250 - 620 + 400 - 25 fee
        // = 5 AED.
        XCTAssertEqual(
            result.reports[2].balances[account.id]?.minorUnits,
            500
        )

        // Auth-A is valid and settles for 185 AED.
        XCTAssertEqual(
            result.authorizations["Auth-A"]?.status,
            .settled
        )

        // Auth-Z has no authorization.
        // E6 must therefore be rejected.
        XCTAssertTrue(
            result.errors.contains {
                $0.eventID == "E6"
            }
        )

        // E8 is evaluated against the actual available balance
        // after E7 has been applied.
        XCTAssertEqual(
            result.authorizations["Auth-B"]?.status,
            .rejected
        )

        XCTAssertTrue(
            result.errors.contains {
                $0.eventID == "E8"
            }
        )

        // E9 reverses E7.
        //
        // Day-6 ledger:
        //
        // 250
        // +400
        // -185
        // -620
        // -25 fee
        // +620 reversal
        // = 440 AED.
        XCTAssertEqual(
            result.reports[5].balances[account.id]?.minorUnits,
            44_000
        )

        // The Day-2 fee remains append-only.
        // Historical Day-2 balance is therefore:
        //
        // 250 - 620 - 25 + 620 = 225 AED.
        XCTAssertEqual(
            result.ledger.balance(
                for: account,
                throughDay: 2
            ).minorUnits,
            22_500
        )

        // E7 remains in the append-only ledger.
        XCTAssertTrue(
            result.ledger.entries.contains {
                $0.sourceEventID == "E7"
            }
        )

        // E9 is a separate append-only entry.
        XCTAssertTrue(
            result.ledger.entries.contains {
                $0.sourceEventID == "E9"
            }
        )

        // E10 posts 10.000 BHD.
        XCTAssertEqual(
            result.ledger.balance(
                for: MALReplay.accounts[1],
                throughDay: 6
            ).minorUnits,
            10_000
        )
    }

    func testAuthorizationHoldDoesNotChangeLedgerBalance() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        let events = [
            ReplayEvent(
                id: "E1",
                bookedDay: 1,
                kind: .credit,
                accountID: account.id,
                currency: .AED,
                amount: Money(
                    currency: .AED,
                    minorUnits: 25_000
                ),
                authorizationID: nil,
                valueDay: 1,
                referencedEventID: nil
            ),

            ReplayEvent(
                id: "E2",
                bookedDay: 2,
                kind: .authorization,
                accountID: account.id,
                currency: .AED,
                amount: Money(
                    currency: .AED,
                    minorUnits: 20_000
                ),
                authorizationID: "Auth-X",
                valueDay: 2,
                referencedEventID: nil
            )
        ]

        let result = EventReplay(
            accounts: [account]
        ).replay(
            events: events,
            throughDay: 2
        )

        XCTAssertEqual(
            result.ledger.balance(
                for: account,
                throughDay: 2
            ).minorUnits,
            25_000
        )

        XCTAssertEqual(
            result.authorizations["Auth-X"]?.status,
            .approved
        )
    }

    func testReplayProducesSixDailyReports() {
        let result = EventReplay(
            accounts: MALReplay.accounts
        ).replay(
            events: MALReplay.events,
            throughDay: 6
        )

        XCTAssertEqual(
            result.reports.map(\.day),
            [1, 2, 3, 4, 5, 6]
        )

        for report in result.reports {
            print(
                """
                DAY \(report.day)
                  BALANCES: \(report.balances)
                  FEES: \(report.fees)
                  AUTHORIZATIONS: \(report.authorizations)
                  ERRORS: \(report.errors)
                """
            )
        }
    }
}
