//
// LedgerInvariant.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import Foundation

struct LedgerInvariant {

    func isBalanced(_ entries: [LedgerEntry]) -> Bool {
        guard !entries.isEmpty else {
            return true
        }

        var balanceBySource: [String: Int64] = [:]

        for entry in entries {
            guard let sourceEventID = entry.sourceEventID else {
                continue
            }

            balanceBySource[sourceEventID, default: 0] += entry.amount.minorUnits
        }

        return balanceBySource.values.allSatisfy { $0 == 0 }
    }
}
