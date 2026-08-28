//
// Money.swift
// account-ledger-core
//
// Created by Afzal on 27/08/2026.
//

import Foundation

struct Money: Equatable, CustomStringConvertible {
    let currency: Currency
    let minorUnits: Int64

    init(currency: Currency, minorUnits: Int64) {
        self.currency = currency
        self.minorUnits = minorUnits
    }

    static func zero(_ currency: Currency) -> Money {
        Money(currency: currency, minorUnits: 0)
    }

    func adding(_ other: Money) -> Money {
        precondition(currency == other.currency, "Currency mismatch")
        return Money(
            currency: currency,
            minorUnits: minorUnits + other.minorUnits
        )
    }

    func subtracting(_ other: Money) -> Money {
        precondition(currency == other.currency, "Currency mismatch")
        return Money(
            currency: currency,
            minorUnits: minorUnits - other.minorUnits
        )
    }

    var description: String {
        let divisor = Int64(pow(10.0, Double(currency.scale)))
        let sign = minorUnits < 0 ? "-" : ""
        let absolute = Swift.abs(minorUnits)

        let major = absolute / divisor
        let minor = absolute % divisor

        return "\(sign)\(major).\(String(format: "%0\(currency.scale)d", minor)) \(currency.rawValue)"
    }
}
