//
// TransactionProcessor.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import Foundation

struct TransactionProcessor {

    func post(
        _ transaction: Transaction,
        to ledger: inout Ledger
    ) {
        let entries = transaction.ledgerEntries()

        let total = entries.reduce(
            Money.zero(transaction.amount.currency)
        ) {
            $0.adding($1.amount)
        }

        precondition(
            total.minorUnits == 0,
            "Double-entry transaction must balance"
        )

        for entry in entries {
            ledger.append(entry)
        }
    }
}
