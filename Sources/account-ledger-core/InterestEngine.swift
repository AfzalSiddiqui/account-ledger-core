import Foundation

struct InterestEngine {

    static let dailyRateNumerator: Int64 = 4
    static let dailyRateDenominator: Int64 = 10_000

    func dailyAccrual(
        for account: Account,
        throughDay day: Int,
        ledger: Ledger
    ) -> Money {
        let balance = ledger.balance(
            for: account,
            throughDay: day
        )

        guard balance.minorUnits > 0 else {
            return .zero(account.currency)
        }

        let numerator =
            balance.minorUnits * Self.dailyRateNumerator

        let rounded =
            (numerator + Self.dailyRateDenominator / 2)
            / Self.dailyRateDenominator

        return Money(
            currency: account.currency,
            minorUnits: rounded
        )
    }

    func dailyAccruals(
        for account: Account,
        throughDay finalDay: Int,
        ledger: Ledger
    ) -> [Money] {
        guard finalDay > 0 else {
            return []
        }

        return (1...finalDay).map {
            dailyAccrual(
                for: account,
                throughDay: $0,
                ledger: ledger
            )
        }
    }

    func capitalizedInterest(
        for account: Account,
        throughDay finalDay: Int,
        ledger: Ledger
    ) -> Money {
        dailyAccruals(
            for: account,
            throughDay: finalDay,
            ledger: ledger
        )
        .reduce(.zero(account.currency)) {
            $0.adding($1)
        }
    }
}
