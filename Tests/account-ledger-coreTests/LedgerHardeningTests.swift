//
// LedgerHardeningTests.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import XCTest
@testable import account_ledger_core

final class LedgerHardeningTests: XCTestCase {

    func testTransactionPostsBothEntriesAtomically() {
        let transaction = Transaction(
            id: "tx-100",
            debitAccountID: "debit",
            creditAccountID: "credit",
            amount: Money(currency: .AED, minorUnits: 5000),
            valueDay: 28
        )

        var ledger = Ledger()
        let processor = TransactionProcessor()

        XCTAssertTrue(
            processor.post(
                transaction,
                to: &ledger
            )
        )

        XCTAssertEqual(ledger.entries.count, 2)
    }

    func testDuplicateTransactionIsNotPostedTwice() {
        let transaction = Transaction(
            id: "tx-101",
            debitAccountID: "account-a",
            creditAccountID: "account-b",
            amount: Money(currency: .AED, minorUnits: 1000),
            valueDay: 28
        )

        var ledger = Ledger()
        let processor = TransactionProcessor()

        XCTAssertTrue(
            processor.post(
                transaction,
                to: &ledger
            )
        )

        XCTAssertFalse(
            processor.post(
                transaction,
                to: &ledger
            )
        )

        XCTAssertEqual(ledger.entries.count, 2)
    }

    func testPostedTransactionIsBalanced() {
        let transaction = Transaction(
            id: "tx-102",
            debitAccountID: "account-a",
            creditAccountID: "account-b",
            amount: Money(currency: .AED, minorUnits: 2500),
            valueDay: 28
        )

        var ledger = Ledger()
        let processor = TransactionProcessor()

        XCTAssertTrue(
            processor.post(
                transaction,
                to: &ledger
            )
        )

        let reconciliation = LedgerReconciliation()

        XCTAssertTrue(
            reconciliation.isBalanced(
                ledger: ledger,
                sourceEventID: transaction.id
            )
        )
    }
}
