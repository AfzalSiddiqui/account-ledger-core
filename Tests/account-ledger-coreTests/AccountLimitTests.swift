//
// AccountLimitTests.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import XCTest
@testable import account_ledger_core

final class AccountLimitTests: XCTestCase {

    func testDebitWithinLimitIsAllowed() {
        let limit = AccountLimit(
            maximumDebit: Money(currency: .AED, minorUnits: 100000)
        )

        let allowed = limit.allows(
            Money(currency: .AED, minorUnits: 50000)
        )

        XCTAssertTrue(allowed)
    }

    func testDebitAtLimitIsAllowed() {
        let limit = AccountLimit(
            maximumDebit: Money(currency: .AED, minorUnits: 100000)
        )

        let allowed = limit.allows(
            Money(currency: .AED, minorUnits: 100000)
        )

        XCTAssertTrue(allowed)
    }

    func testDebitAboveLimitIsRejected() {
        let limit = AccountLimit(
            maximumDebit: Money(currency: .AED, minorUnits: 100000)
        )

        let allowed = limit.allows(
            Money(currency: .AED, minorUnits: 100001)
        )

        XCTAssertFalse(allowed)
    }
}
