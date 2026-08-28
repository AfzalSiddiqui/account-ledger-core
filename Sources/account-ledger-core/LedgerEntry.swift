//
// LedgerEntry.swift
// account-ledger-core
//
// Created by Afzal on 27/08/2026.
//

import Foundation

enum LedgerEntryType: String, Equatable {
    case credit
    case debit
    case fee
    case interest
    case reversal
}

struct LedgerEntry: Equatable {
    let id: String
    let accountID: String
    let amount: Money
    let type: LedgerEntryType
    let valueDay: Int
    let sourceEventID: String?

    init(
        id: String,
        accountID: String,
        amount: Money,
        type: LedgerEntryType,
        valueDay: Int,
        sourceEventID: String? = nil
    ) {
        self.id = id
        self.accountID = accountID
        self.amount = amount
        self.type = type
        self.valueDay = valueDay
        self.sourceEventID = sourceEventID
    }
}
