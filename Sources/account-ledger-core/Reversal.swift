//
// Reversal.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import Foundation

enum ReversalState: Equatable {
    case reversed
    case rejected
}

struct Reversal: Equatable {
    let id: String
    let originalEntryID: String
    let accountID: String
    let amount: Money
    let state: ReversalState
}

struct ReversalEngine {

    func reverse(
        id: String,
        originalEntry: LedgerEntry,
        account: Account
    ) -> Reversal {

        guard originalEntry.accountID == account.id else {
            return Reversal(
                id: id,
                originalEntryID: originalEntry.id,
                accountID: account.id,
                amount: Money.zero(account.currency),
                state: .rejected
            )
        }

        return Reversal(
            id: id,
            originalEntryID: originalEntry.id,
            accountID: account.id,
            amount: originalEntry.amount,
            state: .reversed
        )
    }

    func ledgerEntry(
        for reversal: Reversal,
        valueDay: Int
    ) -> LedgerEntry? {

        guard reversal.state == .reversed else {
            return nil
        }

        return LedgerEntry(
            id: reversal.id,
            accountID: reversal.accountID,
            amount: Money(
                currency: reversal.amount.currency,
                minorUnits: -reversal.amount.minorUnits
            ),
            type: reversal.amount.minorUnits >= 0 ? .debit : .credit,
            valueDay: valueDay,
            sourceEventID: reversal.originalEntryID
        )
    }
}
