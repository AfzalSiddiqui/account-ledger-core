import Foundation

struct InterestCapitalization {

    let engine: InterestEngine

    init(engine: InterestEngine = InterestEngine()) {
        self.engine = engine
    }

    func capitalize(
        for account: Account,
        on day: Int,
        ledger: inout Ledger
    ) -> Money {
        let interest = engine.capitalizedInterest(
            for: account,
            throughDay: day,
            ledger: ledger
        )

        guard interest.minorUnits > 0 else {
            return .zero(account.currency)
        }

        let sourceEventID =
            "INTEREST-CAPITALIZATION-\(account.id)-DAY-\(day)"

        guard !ledger.entries.contains(where: {
            $0.sourceEventID == sourceEventID
        }) else {
            return .zero(account.currency)
        }

        let entry = LedgerEntry(
            id: sourceEventID,
            accountID: account.id,
            amount: interest,
            type: .credit,
            valueDay: day,
            sourceEventID: sourceEventID
        )

        ledger.append(entry)

        return interest
    }
}
