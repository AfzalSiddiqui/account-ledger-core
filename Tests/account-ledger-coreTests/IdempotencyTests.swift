//
// IdempotencyTests.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import XCTest
@testable import account_ledger_core

final class IdempotencyTests: XCTestCase {

    func testFirstTransactionIDIsAccepted() {
        var store = IdempotencyStore()

        let accepted = store.checkAndRecord(
            transactionID: "TX-001"
        )

        XCTAssertTrue(accepted)
    }

    func testDuplicateTransactionIDIsRejected() {
        var store = IdempotencyStore()

        XCTAssertTrue(
            store.checkAndRecord(transactionID: "TX-001")
        )

        XCTAssertFalse(
            store.checkAndRecord(transactionID: "TX-001")
        )
    }

    func testDifferentTransactionIDsAreAccepted() {
        var store = IdempotencyStore()

        XCTAssertTrue(
            store.checkAndRecord(transactionID: "TX-001")
        )

        XCTAssertTrue(
            store.checkAndRecord(transactionID: "TX-002")
        )
    }

    func testDuplicateTransactionDoesNotCreateAdditionalRecord() {
        var store = IdempotencyStore()

        _ = store.checkAndRecord(transactionID: "TX-001")
        _ = store.checkAndRecord(transactionID: "TX-001")

        XCTAssertEqual(
            store.processedTransactionIDs.count,
            1
        )
    }
}
