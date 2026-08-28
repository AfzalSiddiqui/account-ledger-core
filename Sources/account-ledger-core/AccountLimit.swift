//
// AccountLimit.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import Foundation

struct AccountLimit: Equatable {

    let maximumDebit: Money

    func allows(_ amount: Money) -> Bool {
        precondition(
            amount.currency == maximumDebit.currency,
            "Currency mismatch"
        )

        return amount.minorUnits <= maximumDebit.minorUnits
    }
}
