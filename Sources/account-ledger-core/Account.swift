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