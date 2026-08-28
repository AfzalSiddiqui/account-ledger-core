//
// Authorization.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import Foundation

enum AuthorizationState: Equatable {
    case approved
    case rejected
}

struct Authorization {
    let id: String
    let accountID: String
    let amount: Money
    let state: AuthorizationState
}

struct AuthorizationEngine {

    func authorize(
        id: String,
        account: Account,
        ledger: Ledger,
        holdAmount: Money,
        activeHolds: [Money],
        throughDay day: Int
    ) -> Authorization {

        let ledgerBalance = ledger.balance(
            for: account,
            throughDay: day
        )

        let existingHolds = activeHolds.reduce(
            Money.zero(account.currency)
        ) {
            $0.adding($1)
        }

        let available = ledgerBalance
            .subtracting(existingHolds)
            .subtracting(holdAmount)

        let state: AuthorizationState =
            available.minorUnits < 0 ? .rejected : .approved

        return Authorization(
            id: id,
            accountID: account.id,
            amount: holdAmount,
            state: state
        )
    }
}
