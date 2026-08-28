//
// LedgerReconciliation.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import Foundation

struct LedgerReconciliation {

    func isBalanced(
        ledger: Ledger,
        sourceEventID: String
    ) -> Bool {
        let entries = ledger.entries.filter {
            $0.sourceEventID == sourceEventID
        }

        guard !entries.isEmpty else {
            return false
        }

        return entries.reduce(Int64(0)) {
            $0 + $1.amount.minorUnits
        } == 0
    }
}
