import Foundation

struct Ledger {
    private(set) var entries: [LedgerEntry] = []

    mutating func append(_ entry: LedgerEntry) {
        entries.append(entry)
    }

    func entries(
        for accountID: String,
        throughDay day: Int
    ) -> [LedgerEntry] {
        entries.filter {
            $0.accountID == accountID &&
            $0.valueDay <= day
        }
    }

    func balance(
        for account: Account,
        throughDay day: Int
    ) -> Money {
        entries(for: account.id, throughDay: day)
            .reduce(account.openingBalance) {
                $0.adding($1.amount)
            }
    }
}
