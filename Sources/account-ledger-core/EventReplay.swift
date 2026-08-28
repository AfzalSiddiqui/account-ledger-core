import Foundation

enum ReplayEventKind: Equatable {
    case credit
    case debit
    case authorization
    case settlement
    case reversal
}

struct ReplayEvent {
    let id: String
    let bookedDay: Int
    let kind: ReplayEventKind
    let accountID: String
    let currency: Currency
    let amount: Money?
    let authorizationID: String?
    let valueDay: Int
    let referencedEventID: String?
}

enum AuthorizationStatus: Equatable {
    case approved
    case rejected
    case settled
    case active
}

struct AuthorizationRecord: Equatable {
    let id: String
    let accountID: String
    let amount: Money
    let bookedDay: Int
    var status: AuthorizationStatus
}

struct ReplayError: Equatable {
    let eventID: String
    let day: Int
    let message: String
}

struct DailyReplayReport: Equatable {
    let day: Int
    let balances: [String: Money]
    let fees: [String: Money]
    let authorizations: [String: AuthorizationStatus]
    let errors: [ReplayError]
}

struct ReplayResult {
    let ledger: Ledger
    let reports: [DailyReplayReport]
    let errors: [ReplayError]
    let authorizations: [String: AuthorizationRecord]
}

struct EventReplay {

    let accounts: [String: Account]
    let overdraftFeeEngine: OverdraftFeeEngine

    init(
        accounts: [Account],
        overdraftFeeEngine: OverdraftFeeEngine = OverdraftFeeEngine()
    ) {
        self.accounts = Dictionary(
            uniqueKeysWithValues: accounts.map { ($0.id, $0) }
        )
        self.overdraftFeeEngine = overdraftFeeEngine
    }

    func replay(
        events: [ReplayEvent],
        throughDay finalDay: Int = 6
    ) -> ReplayResult {

        var ledger = Ledger()
        var authorizations: [String: AuthorizationRecord] = [:]
        var errors: [ReplayError] = []
        var reports: [DailyReplayReport] = []

        for day in 1...finalDay {

            let dayEvents = events.filter {
                $0.bookedDay == day
            }

            for event in dayEvents {
                process(
                    event,
                    ledger: &ledger,
                    authorizations: &authorizations,
                    errors: &errors
                )
            }

            // Fees are assessed retroactively for all days up to
            // the current processing day. A back-dated debit (like E7)
            // can make historical day balances negative, requiring
            // cascading fee assessment.
            for assessDay in 1...day {
                for account in accounts.values {
                    _ = overdraftFeeEngine.assess(
                        for: account,
                        throughDay: assessDay,
                        ledger: &ledger
                    )
                }
            }

            var balances: [String: Money] = [:]
            var fees: [String: Money] = [:]

            for account in accounts.values {
                balances[account.id] = ledger.balance(
                    for: account,
                    throughDay: day
                )

                let feeEntries = ledger.entries.filter {
                    $0.accountID == account.id &&
                    $0.valueDay == day &&
                    $0.sourceEventID?.hasPrefix("OVERDRAFT-FEE-") == true
                }

                fees[account.id] = feeEntries.reduce(
                    .zero(account.currency)
                ) {
                    $0.adding($1.amount)
                }
            }

            let states = Dictionary(
                uniqueKeysWithValues: authorizations.values.map {
                    ($0.id, $0.status)
                }
            )

            reports.append(
                DailyReplayReport(
                    day: day,
                    balances: balances,
                    fees: fees,
                    authorizations: states,
                    errors: errors.filter {
                        $0.day == day
                    }
                )
            )
        }

        return ReplayResult(
            ledger: ledger,
            reports: reports,
            errors: errors,
            authorizations: authorizations
        )
    }

    private func process(
        _ event: ReplayEvent,
        ledger: inout Ledger,
        authorizations: inout [String: AuthorizationRecord],
        errors: inout [ReplayError]
    ) {
        guard let account = accounts[event.accountID] else {
            errors.append(
                ReplayError(
                    eventID: event.id,
                    day: event.bookedDay,
                    message: "Unknown account \(event.accountID)"
                )
            )
            return
        }

        switch event.kind {

        case .credit:
            guard let amount = event.amount else {
                addError(
                    event,
                    message: "Credit is missing amount",
                    errors: &errors
                )
                return
            }

            append(
                id: event.id,
                account: account,
                amount: amount,
                type: .credit,
                valueDay: event.valueDay,
                ledger: &ledger
            )

        case .debit:
            guard let amount = event.amount else {
                addError(
                    event,
                    message: "Debit is missing amount",
                    errors: &errors
                )
                return
            }

            append(
                id: event.id,
                account: account,
                amount: Money(
                    currency: amount.currency,
                    minorUnits: -amount.minorUnits
                ),
                type: .debit,
                valueDay: event.valueDay,
                ledger: &ledger
            )

        case .authorization:
            guard
                let authorizationID = event.authorizationID,
                let amount = event.amount
            else {
                addError(
                    event,
                    message: "Authorization is missing ID or amount",
                    errors: &errors
                )
                return
            }

            let ledgerBalance = ledger.balance(
                for: account,
                throughDay: event.valueDay
            )

            let activeHolds = authorizations.values
                .filter {
                    $0.accountID == account.id &&
                    $0.status == .approved
                }
                .reduce(Int64(0)) {
                    $0 + $1.amount.minorUnits
                }

            let available =
                ledgerBalance.minorUnits -
                activeHolds -
                amount.minorUnits

            guard available >= 0 else {
                authorizations[authorizationID] =
                    AuthorizationRecord(
                        id: authorizationID,
                        accountID: account.id,
                        amount: amount,
                        bookedDay: event.bookedDay,
                        status: .rejected
                    )

                addError(
                    event,
                    message: "Authorization \(authorizationID) rejected: insufficient available balance",
                    errors: &errors
                )
                return
            }

            authorizations[authorizationID] =
                AuthorizationRecord(
                    id: authorizationID,
                    accountID: account.id,
                    amount: amount,
                    bookedDay: event.bookedDay,
                    status: .approved
                )

        case .settlement:
            guard let authorizationID = event.authorizationID else {
                addError(
                    event,
                    message: "Settlement is missing authorization ID",
                    errors: &errors
                )
                return
            }

            guard var authorization =
                    authorizations[authorizationID] else {
                addError(
                    event,
                    message: "Settlement rejected: authorization \(authorizationID) does not exist",
                    errors: &errors
                )
                return
            }

            guard authorization.status == .approved else {
                addError(
                    event,
                    message: "Settlement rejected: authorization \(authorizationID) is not approved",
                    errors: &errors
                )
                return
            }

            guard let amount = event.amount else {
                addError(
                    event,
                    message: "Settlement is missing amount",
                    errors: &errors
                )
                return
            }

            guard amount.currency == authorization.amount.currency else {
                addError(
                    event,
                    message: "Settlement currency mismatch",
                    errors: &errors
                )
                return
            }

            guard amount.minorUnits <= authorization.amount.minorUnits else {
                addError(
                    event,
                    message: "Settlement exceeds authorization amount",
                    errors: &errors
                )
                return
            }

            append(
                id: event.id,
                account: account,
                amount: Money(
                    currency: amount.currency,
                    minorUnits: -amount.minorUnits
                ),
                type: .debit,
                valueDay: event.valueDay,
                ledger: &ledger
            )

            authorization.status = .settled
            authorizations[authorizationID] = authorization

        case .reversal:
            guard let originalID = event.referencedEventID else {
                addError(
                    event,
                    message: "Reversal is missing original event ID",
                    errors: &errors
                )
                return
            }

            guard let original = ledger.entries.first(where: {
                $0.sourceEventID == originalID
            }) else {
                addError(
                    event,
                    message: "Reversal rejected: original event \(originalID) not found",
                    errors: &errors
                )
                return
            }

            let reversalAmount = Money(
                currency: original.amount.currency,
                minorUnits: -original.amount.minorUnits
            )

            append(
                id: event.id,
                account: account,
                amount: reversalAmount,
                type: reversalAmount.minorUnits >= 0 ? .credit : .debit,
                valueDay: event.valueDay,
                ledger: &ledger
            )
        }
    }

    private func append(
        id: String,
        account: Account,
        amount: Money,
        type: LedgerEntryType,
        valueDay: Int,
        ledger: inout Ledger
    ) {
        ledger.append(
            LedgerEntry(
                id: id,
                accountID: account.id,
                amount: amount,
                type: type,
                valueDay: valueDay,
                sourceEventID: id
            )
        )
    }

    private func addError(
        _ event: ReplayEvent,
        message: String,
        errors: inout [ReplayError]
    ) {
        errors.append(
            ReplayError(
                eventID: event.id,
                day: event.bookedDay,
                message: message
            )
        )
    }
}
