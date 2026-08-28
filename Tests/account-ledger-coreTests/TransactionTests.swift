//
// TransactionTests.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import XCTest
@testable import account_ledger_core

final class TransactionTests: XCTestCase {

    func testTransactionCreatesBalancedDebitAndCredit() {
        let transaction = Transaction(
            id: "TX-001",
            debitAccountID: "ACC-001",
            creditAccountID: "ACC-002",
            amount: Money(
                currency: .AED,
                minorUnits: 10000
            ),
            valueDay: 1
        )

        let entries = transaction.ledgerEntries()

        XCTAssertEqual(entries.count, 2)

        XCTAssertEqual(entries[0].accountID, "ACC-001")
        XCTAssertEqual(entries[0].amount.minorUnits, -10000)
        XCTAssertEqual(entries[0].type, .debit)

        XCTAssertEqual(entries[1].accountID, "ACC-002")
        XCTAssertEqual(entries[1].amount.minorUnits, 10000)
        XCTAssertEqual(entries[1].type, .credit)
    }

    func testTransactionIsBalanced() {
        let transaction = Transaction(
            id: "TX-002",
            debitAccountID: "ACC-001",
            creditAccountID: "ACC-002",
            amount: Money(
                currency: .AED,
                minorUnits: 25000
            ),
            valueDay: 1
        )

        let entries = transaction.ledgerEntries()

        let total = entries.reduce(
            Money.zero(.AED)
        ) {
            $0.adding($1.amount)
        }

        XCTAssertEqual(total.minorUnits, 0)
    }

    func testTransactionPreservesSourceEventID() {
        let transaction = Transaction(
            id: "TX-003",
            debitAccountID: "ACC-001",
            creditAccountID: "ACC-002",
            amount: Money(
                currency: .AED,
                minorUnits: 10000
            ),
            valueDay: 1
        )

        let entries = transaction.ledgerEntries()

        XCTAssertEqual(entries[0].sourceEventID, "TX-003")
        XCTAssertEqual(entries[1].sourceEventID, "TX-003")
    }

    func testTransactionPreservesValueDay() {
        let transaction = Transaction(
            id: "TX-004",
            debitAccountID: "ACC-001",
            creditAccountID: "ACC-002",
            amount: Money(
                currency: .AED,
                minorUnits: 50000
            ),
            valueDay: 7
        )

        let entries = transaction.ledgerEntries()

        XCTAssertEqual(entries[0].valueDay, 7)
        XCTAssertEqual(entries[1].valueDay, 7)
    }
}

extension TransactionTests {

    func testTransactionPostsBothEntriesToLedger() {
        let accountA = Account(
            id: "ACC-001",
            currency: .AED
        )

        let accountB = Account(
            id: "ACC-002",
            currency: .AED
        )

        let transaction = Transaction(
            id: "TX-005",
            debitAccountID: accountA.id,
            creditAccountID: accountB.id,
            amount: Money(
                currency: .AED,
                minorUnits: 50000
            ),
            valueDay: 1
        )

        var ledger = Ledger()

        let processor = TransactionProcessor()

        processor.post(
            transaction,
            to: &ledger
        )

        XCTAssertEqual(ledger.entries.count, 2)

        XCTAssertEqual(
            ledger.balance(
                for: accountA,
                throughDay: 1
            ).minorUnits,
            -50000
        )

        XCTAssertEqual(
            ledger.balance(
                for: accountB,
                throughDay: 1
            ).minorUnits,
            50000
        )
    }

    func testTransactionEntriesShareTransactionIDAsSourceEvent() {
        let transaction = Transaction(
            id: "TX-006",
            debitAccountID: "ACC-001",
            creditAccountID: "ACC-002",
            amount: Money(
                currency: .AED,
                minorUnits: 7500
            ),
            valueDay: 2
        )

        var ledger = Ledger()

        let processor = TransactionProcessor()

        processor.post(
            transaction,
            to: &ledger
        )

        XCTAssertEqual(ledger.entries.count, 2)

        XCTAssertEqual(
            ledger.entries[0].sourceEventID,
            transaction.id
        )

        XCTAssertEqual(
            ledger.entries[1].sourceEventID,
            transaction.id
        )
    }
}
