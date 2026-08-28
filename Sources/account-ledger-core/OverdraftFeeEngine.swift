import Foundation

struct OverdraftFeeEngine {

    let fee: Money

    init(fee: Money = Money(currency: .AED, minorUnits: 2_500)) {
        self.fee = fee
    }

    func assess(
        for account: Account,
        throughDay day: Int,
        ledger: inout Ledger
    ) -> Bool {
        guard account.currency == fee.currency else {
            return false
        }

        let balance = ledger.balance(
            for: account,
            throughDay: day
        )

        guard balance.minorUnits < 0 else {
            return false
        }

        let sourceEventID = "OVERDRAFT-FEE-\(account.id)-DAY-\(day)"

        guard !ledger.entries.contains(where: {
            $0.sourceEventID == sourceEventID
        }) else {
            return false
        }

        let entry = LedgerEntry(
            id: sourceEventID,
            accountID: account.id,
            amount: Money(
                currency: account.currency,
                minorUnits: -fee.minorUnits
            ),
            type: .fee,
            valueDay: day,
            sourceEventID: sourceEventID
        )

        ledger.append(entry)
        return true
    }
}
