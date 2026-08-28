//
// Account.swift
// account-ledger-core
//
// Created by Afzal on 27/08/2026.
//

import Foundation

struct Account: Equatable {
    let id: String
    let currency: Currency
    let openingBalance: Money

    init(id: String, currency: Currency) {
        self.id = id
        self.currency = currency
        self.openingBalance = .zero(currency)
    }
}