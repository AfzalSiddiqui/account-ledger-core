import Foundation

enum MALReplay {

    static let accounts = [
        Account(id: "ACC-001", currency: .AED),
        Account(id: "ACC-002", currency: .BHD)
    ]

    static let events: [ReplayEvent] = {
        let aed = Currency.AED
        let bhd = Currency.BHD

        return [
            ReplayEvent(
                id: "E1",
                bookedDay: 1,
                kind: .credit,
                accountID: "ACC-001",
                currency: aed,
                amount: Money(currency: aed, minorUnits: 120_000),
                authorizationID: nil,
                valueDay: 1,
                referencedEventID: nil
            ),

            ReplayEvent(
                id: "E2",
                bookedDay: 1,
                kind: .debit,
                accountID: "ACC-001",
                currency: aed,
                amount: Money(currency: aed, minorUnits: 95_000),
                authorizationID: nil,
                valueDay: 1,
                referencedEventID: nil
            ),

            ReplayEvent(
                id: "E3",
                bookedDay: 2,
                kind: .authorization,
                accountID: "ACC-001",
                currency: aed,
                amount: Money(currency: aed, minorUnits: 20_000),
                authorizationID: "Auth-A",
                valueDay: 2,
                referencedEventID: nil
            ),

            ReplayEvent(
                id: "E4",
                bookedDay: 3,
                kind: .credit,
                accountID: "ACC-001",
                currency: aed,
                amount: Money(currency: aed, minorUnits: 40_000),
                authorizationID: nil,
                valueDay: 3,
                referencedEventID: nil
            ),

            ReplayEvent(
                id: "E5",
                bookedDay: 4,
                kind: .settlement,
                accountID: "ACC-001",
                currency: aed,
                amount: Money(currency: aed, minorUnits: 18_500),
                authorizationID: "Auth-A",
                valueDay: 4,
                referencedEventID: nil
            ),

            ReplayEvent(
                id: "E6",
                bookedDay: 4,
                kind: .settlement,
                accountID: "ACC-001",
                currency: aed,
                amount: Money(currency: aed, minorUnits: 18_000),
                authorizationID: "Auth-Z",
                valueDay: 4,
                referencedEventID: nil
            ),

            ReplayEvent(
                id: "E7",
                bookedDay: 5,
                kind: .debit,
                accountID: "ACC-001",
                currency: aed,
                amount: Money(currency: aed, minorUnits: 62_000),
                authorizationID: nil,
                valueDay: 2,
                referencedEventID: nil
            ),

            ReplayEvent(
                id: "E8",
                bookedDay: 5,
                kind: .authorization,
                accountID: "ACC-001",
                currency: aed,
                amount: Money(currency: aed, minorUnits: 9_000),
                authorizationID: "Auth-B",
                valueDay: 5,
                referencedEventID: nil
            ),

            ReplayEvent(
                id: "E9",
                bookedDay: 6,
                kind: .reversal,
                accountID: "ACC-001",
                currency: aed,
                amount: nil,
                authorizationID: nil,
                valueDay: 2,
                referencedEventID: "E7"
            ),

            ReplayEvent(
                id: "E10",
                bookedDay: 5,
                kind: .credit,
                accountID: "ACC-002",
                currency: bhd,
                amount: Money(currency: bhd, minorUnits: 10_000),
                authorizationID: nil,
                valueDay: 5,
                referencedEventID: nil,
                instalments: 3
            )
        ]
    }()
}
