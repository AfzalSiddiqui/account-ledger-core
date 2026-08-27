import Foundation

enum SettlementState: Equatable {
    case settled
    case rejected
}

struct Settlement: Equatable {
    let id: String
    let authorizationID: String
    let accountID: String
    let amount: Money
    let state: SettlementState
}

struct SettlementEngine {

    func settle(
        id: String,
        authorization: Authorization,
        account: Account
    ) -> Settlement {

        guard authorization.state == .approved else {
            return Settlement(
                id: id,
                authorizationID: authorization.id,
                accountID: account.id,
                amount: Money.zero(account.currency),
                state: .rejected
            )
        }

        return Settlement(
            id: id,
            authorizationID: authorization.id,
            accountID: account.id,
            amount: authorization.amount,
            state: .settled
        )
    }

    func ledgerEntry(
        for settlement: Settlement,
        valueDay: Int
    ) -> LedgerEntry? {

        guard settlement.state == .settled else {
            return nil
        }

        return LedgerEntry(
            id: settlement.id,
            accountID: settlement.accountID,
            amount: Money(
                currency: settlement.amount.currency,
                minorUnits: -settlement.amount.minorUnits
            ),
            type: .debit,
            valueDay: valueDay,
            sourceEventID: settlement.authorizationID
        )
    }
}
