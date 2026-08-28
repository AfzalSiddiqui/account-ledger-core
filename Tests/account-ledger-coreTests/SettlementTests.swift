//
// SettlementTests.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import XCTest
@testable import account_ledger_core

final class SettlementTests: XCTestCase {

    func testSettlementCreatesDebitFromAuthorization() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        let authorization = Authorization(
            id: "AUTH-A",
            accountID: account.id,
            amount: Money(currency: .AED, minorUnits: 18500),
            state: .approved
        )

        let engine = SettlementEngine()

        let settlement = engine.settle(
            id: "SET-001",
            authorization: authorization,
            account: account
        )

        let entry = engine.ledgerEntry(
            for: settlement,
            valueDay: 4
        )

        XCTAssertEqual(settlement.state, .settled)
        XCTAssertEqual(settlement.authorizationID, "AUTH-A")
        XCTAssertEqual(entry?.amount.minorUnits, -18500)
        XCTAssertEqual(entry?.type, .debit)
        XCTAssertEqual(entry?.sourceEventID, "AUTH-A")
    }

    func testRejectedAuthorizationCannotSettle() {
        let account = Account(
            id: "ACC-001",
            currency: .AED
        )

        let authorization = Authorization(
            id: "AUTH-Z",
            accountID: account.id,
            amount: Money(currency: .AED, minorUnits: 50000),
            state: .rejected
        )

        let engine = SettlementEngine()

        let settlement = engine.settle(
            id: "SET-Z",
            authorization: authorization,
            account: account
        )

        XCTAssertEqual(settlement.state, .rejected)
        XCTAssertNil(
            engine.ledgerEntry(
                for: settlement,
                valueDay: 4
            )
        )
    }
}
