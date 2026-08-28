//
// Transaction.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import Foundation

struct Transaction: Equatable {

    let id: String
    let debitAccountID: String
    let creditAccountID: String
    let amount: Money
    let valueDay: Int

    init(
        id: String,
        debitAccountID: String,
        creditAccountID: String,
        amount: Money,
        valueDay: Int
    ) {
        precondition(amount.minorUnits > 0, "Transaction amount must be positive")
        precondition(
            debitAccountID != creditAccountID,
            "Debit and credit accounts must be different"
        )

        self.id = id
        self.debitAccountID = debitAccountID
        self.creditAccountID = creditAccountID
        self.amount = amount
        self.valueDay = valueDay
    }

    func ledgerEntries() -> [LedgerEntry] {
        [
            LedgerEntry(
                id: "\(id)-debit",
                accountID: debitAccountID,
                amount: Money(
                    currency: amount.currency,
                    minorUnits: -amount.minorUnits
                ),
                type: .debit,
                valueDay: valueDay,
                sourceEventID: id
            ),
            LedgerEntry(
                id: "\(id)-credit",
                accountID: creditAccountID,
                amount: amount,
                type: .credit,
                valueDay: valueDay,
                sourceEventID: id
            )
        ]
    }
}
