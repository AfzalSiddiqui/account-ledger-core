//
// EventProcessor.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import Foundation

struct EventProcessor {

    private(set) var ledger = Ledger()
    private(set) var accounts: [String: Account] = [:]
    private(set) var authorizations: [String: Authorization] = [:]
    private(set) var activeHolds: [String: [Money]] = [:]
    private(set) var errors: [(day: Int, eventID: String, message: String)] = []
    private(set) var dailyInterestAccruals: [String: [(day: Int, amount: Money)]] = [:]
    private var feeAssessedDays: [String: Set<Int>] = [:]

    private let overdraftFeeEngine = OverdraftFeeEngine()
    private let interestEngine = InterestEngine()
    private let authorizationEngine = AuthorizationEngine()
    private let settlementEngine = SettlementEngine()
    private let reversalEngine = ReversalEngine()
    private let capitalization = InterestCapitalization()

    mutating func process(events: [Event]) {
        let grouped = Dictionary(grouping: events) { $0.day }
        let days = grouped.keys.sorted()
        let maxDay = days.last ?? 0

        for day in 1...max(maxDay, 6) {
            if let dayEvents = grouped[day] {
                for event in dayEvents {
                    ensureAccount(event: event)
                    processEvent(event)
                }
            }

            assessOverdraftFees(throughDay: day)

            printDayReport(day: day)
        }

        computeFinalDailyInterest(throughDay: 6)
        capitalizeInterest(onDay: 6)
        printFinalSummary()
    }

    private mutating func ensureAccount(event: Event) {
        if accounts[event.accountID] == nil {
            accounts[event.accountID] = Account(
                id: event.accountID,
                currency: event.amount.currency
            )
        }
    }

    private mutating func processEvent(_ event: Event) {
        switch event.type {
        case .credit:
            processCredit(event)
        case .debit:
            processDebit(event)
        case .authorization:
            processAuthorization(event)
        case .settlement:
            processSettlement(event)
        case .reversal:
            processReversal(event)
        }
    }

    // MARK: - Credit

    private mutating func processCredit(_ event: Event) {
        if let instalments = event.instalments, instalments > 1 {
            processInstalmentCredit(event, count: instalments)
        } else {
            let entry = LedgerEntry(
                id: event.id,
                accountID: event.accountID,
                amount: event.amount,
                type: .credit,
                valueDay: event.valueDay,
                sourceEventID: event.id
            )
            ledger.append(entry)
        }
    }

    private mutating func processInstalmentCredit(
        _ event: Event,
        count: Int
    ) {
        let totalMinor = event.amount.minorUnits
        let perInstalment = totalMinor / Int64(count)
        var remaining = totalMinor

        for i in 0..<count {
            let isLast = (i == count - 1)
            let amount = isLast ? remaining : perInstalment
            remaining -= amount

            let entry = LedgerEntry(
                id: "\(event.id)-instalment-\(i + 1)",
                accountID: event.accountID,
                amount: Money(
                    currency: event.amount.currency,
                    minorUnits: amount
                ),
                type: .credit,
                valueDay: event.valueDay,
                sourceEventID: event.id
            )
            ledger.append(entry)
        }
    }

    // MARK: - Debit

    private mutating func processDebit(_ event: Event) {
        let entry = LedgerEntry(
            id: event.id,
            accountID: event.accountID,
            amount: Money(
                currency: event.amount.currency,
                minorUnits: -event.amount.minorUnits
            ),
            type: .debit,
            valueDay: event.valueDay,
            sourceEventID: event.id
        )
        ledger.append(entry)
    }

    // MARK: - Authorization

    private mutating func processAuthorization(_ event: Event) {
        guard let authID = event.authorizationID else { return }
        guard let account = accounts[event.accountID] else { return }

        let holds = activeHolds[event.accountID] ?? []

        let auth = authorizationEngine.authorize(
            id: authID,
            account: account,
            ledger: ledger,
            holdAmount: event.amount,
            activeHolds: holds,
            throughDay: event.valueDay
        )

        authorizations[authID] = auth

        if auth.state == .approved {
            activeHolds[event.accountID, default: []].append(
                event.amount
            )
        }
    }

    // MARK: - Settlement

    private mutating func processSettlement(_ event: Event) {
        guard let authID = event.authorizationID else { return }
        guard let account = accounts[event.accountID] else { return }

        guard let auth = authorizations[authID] else {
            errors.append((
                day: event.day,
                eventID: event.id,
                message: "Settlement rejected: unknown authorization \(authID)"
            ))
            return
        }

        let settlement: Settlement
        if let customAmount = event.settlementAmount {
            settlement = settlementEngine.settle(
                id: event.id,
                authorization: auth,
                account: account,
                settlementAmount: customAmount
            )
        } else {
            settlement = settlementEngine.settle(
                id: event.id,
                authorization: auth,
                account: account
            )
        }

        if settlement.state == .rejected {
            errors.append((
                day: event.day,
                eventID: event.id,
                message: "Settlement rejected: authorization \(authID) was not approved"
            ))
            return
        }

        if let entry = settlementEngine.ledgerEntry(
            for: settlement,
            valueDay: event.valueDay
        ) {
            ledger.append(entry)
        }

        authorizations[authID] = Authorization(
            id: auth.id,
            accountID: auth.accountID,
            amount: auth.amount,
            state: .settled
        )

        releaseHold(
            accountID: event.accountID,
            amount: auth.amount
        )
    }

    private mutating func releaseHold(
        accountID: String,
        amount: Money
    ) {
        guard var holds = activeHolds[accountID] else { return }
        if let index = holds.firstIndex(of: amount) {
            holds.remove(at: index)
            activeHolds[accountID] = holds
        }
    }

    // MARK: - Reversal

    private mutating func processReversal(_ event: Event) {
        guard let reversesID = event.reversesEventID else { return }
        guard let account = accounts[event.accountID] else { return }

        guard let originalEntry = ledger.entries.first(where: {
            $0.sourceEventID == reversesID &&
            $0.accountID == event.accountID
        }) else {
            errors.append((
                day: event.day,
                eventID: event.id,
                message: "Reversal rejected: no entry found for event \(reversesID)"
            ))
            return
        }

        let reversal = reversalEngine.reverse(
            id: event.id,
            originalEntry: originalEntry,
            account: account
        )

        if let entry = reversalEngine.ledgerEntry(
            for: reversal,
            valueDay: event.valueDay
        ) {
            ledger.append(entry)
        }
    }

    // MARK: - Overdraft Fees

    private mutating func assessOverdraftFees(throughDay currentDay: Int) {
        for (accountID, account) in accounts {
            guard account.currency == .AED else { continue }

            for day in 1...currentDay {
                if feeAssessedDays[accountID, default: []].contains(day) {
                    continue
                }

                let assessed = overdraftFeeEngine.assess(
                    for: account,
                    throughDay: day,
                    ledger: &ledger
                )

                if assessed {
                    feeAssessedDays[accountID, default: []].insert(day)
                }
            }
        }
    }

    // MARK: - Interest

    private mutating func computeFinalDailyInterest(throughDay finalDay: Int) {
        dailyInterestAccruals = [:]
        for (_, account) in accounts {
            for day in 1...finalDay {
                let accrual = interestEngine.dailyAccrual(
                    for: account,
                    throughDay: day,
                    ledger: ledger
                )

                if accrual.minorUnits > 0 {
                    dailyInterestAccruals[account.id, default: []].append(
                        (day: day, amount: accrual)
                    )
                }
            }
        }
    }

    private mutating func capitalizeInterest(onDay day: Int) {
        for (_, account) in accounts {
            _ = capitalization.capitalize(
                for: account,
                on: day,
                ledger: &ledger
            )
        }
    }

    // MARK: - Reporting

    private func printDayReport(day: Int) {
        print("═══════════════════════════════════════")
        print("  Day \(day) Report")
        print("═══════════════════════════════════════")

        for (accountID, account) in accounts.sorted(by: { $0.key < $1.key }) {
            let balance = ledger.balance(
                for: account,
                throughDay: day
            )
            print("  \(accountID): Closing balance = \(balance)")

            let holds = activeHolds[accountID] ?? []
            if !holds.isEmpty {
                let totalHolds = holds.reduce(
                    Money.zero(account.currency)
                ) { $0.adding($1) }
                let available = balance.subtracting(totalHolds)
                print("    Active holds: \(totalHolds)")
                print("    Available: \(available)")
            }
        }

        let dayFees = ledger.entries.filter {
            $0.type == .fee && $0.valueDay == day
        }
        if !dayFees.isEmpty {
            print("  Fees assessed:")
            for fee in dayFees {
                print("    \(fee.accountID): \(fee.amount)")
            }
        }

        let dayErrors = errors.filter { $0.day == day }
        if !dayErrors.isEmpty {
            print("  Errors:")
            for error in dayErrors {
                print("    [\(error.eventID)] \(error.message)")
            }
        }

        print("")
    }

    private func printFinalSummary() {
        print("═══════════════════════════════════════")
        print("  Final Summary (After Day 6)")
        print("═══════════════════════════════════════")

        for (accountID, account) in accounts.sorted(by: { $0.key < $1.key }) {
            let balance = ledger.balance(
                for: account,
                throughDay: 6
            )
            print("  \(accountID): Final balance = \(balance)")
        }

        print("")
        print("  Authorization States:")
        for (authID, auth) in authorizations.sorted(by: { $0.key < $1.key }) {
            print("    \(authID): \(auth.state)")
        }

        print("")
        print("  Ledger Entries:")
        for entry in ledger.entries {
            print("    [\(entry.id)] \(entry.accountID) \(entry.amount) " +
                  "type=\(entry.type.rawValue) valueDay=\(entry.valueDay)")
        }

        if !errors.isEmpty {
            print("")
            print("  All Errors:")
            for error in errors {
                print("    Day \(error.day) [\(error.eventID)] \(error.message)")
            }
        }

        print("")
        print("  Daily Interest Accruals:")
        for (accountID, accruals) in dailyInterestAccruals.sorted(by: { $0.key < $1.key }) {
            print("    \(accountID):")
            for accrual in accruals {
                print("      Day \(accrual.day): \(accrual.amount)")
            }
            let total = accruals.reduce(
                Money.zero(accruals[0].amount.currency)
            ) { $0.adding($1.amount) }
            print("      Capitalized total: \(total)")
        }
    }
}
