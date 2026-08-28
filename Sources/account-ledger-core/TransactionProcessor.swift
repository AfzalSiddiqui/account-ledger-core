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
    ) -> Bool {
        let entries = transaction.ledgerEntries()

        guard entries.count == 2 else {
            return false
        }

        guard entries[0].amount.currency == entries[1].amount.currency else {
            return false
        }

        guard entries[0].amount.minorUnits +
              entries[1].amount.minorUnits == 0 else {
            return false
        }

        guard !ledger.entries.contains(where: {
            $0.sourceEventID == transaction.id
        }) else {
            return false
        }

        ledger.append(entries[0])
        ledger.append(entries[1])

        return true
    }
}
