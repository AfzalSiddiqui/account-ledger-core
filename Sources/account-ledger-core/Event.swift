//
// Event.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import Foundation

enum EventType: String {
    case credit
    case debit
    case authorization
    case settlement
    case reversal
}

struct Event {
    let id: String
    let day: Int
    let type: EventType
    let accountID: String
    let amount: Money
    let valueDay: Int
    let authorizationID: String?
    let reversesEventID: String?
    let instalments: Int?
    let settlementAmount: Money?

    init(
        id: String,
        day: Int,
        type: EventType,
        accountID: String,
        amount: Money,
        valueDay: Int,
        authorizationID: String? = nil,
        reversesEventID: String? = nil,
        instalments: Int? = nil,
        settlementAmount: Money? = nil
    ) {
        self.id = id
        self.day = day
        self.type = type
        self.accountID = accountID
        self.amount = amount
        self.valueDay = valueDay
        self.authorizationID = authorizationID
        self.reversesEventID = reversesEventID
        self.instalments = instalments
        self.settlementAmount = settlementAmount
    }

    static func eventStream() -> [Event] {
        let aed = Currency.AED
        let bhd = Currency.BHD

        return [
            // E1: Day 1 — Credit AED 1200.00, value day 1
            Event(
                id: "E1",
                day: 1,
                type: .credit,
                accountID: "ACC-001",
                amount: Money(currency: aed, minorUnits: 120_000),
                valueDay: 1
            ),

            // E2: Day 1 — Debit AED 950.00, value day 1
            Event(
                id: "E2",
                day: 1,
                type: .debit,
                accountID: "ACC-001",
                amount: Money(currency: aed, minorUnits: 95_000),
                valueDay: 1
            ),

            // E3: Day 2 — Authorization Auth-A for AED 200.00
            Event(
                id: "E3",
                day: 2,
                type: .authorization,
                accountID: "ACC-001",
                amount: Money(currency: aed, minorUnits: 20_000),
                valueDay: 2,
                authorizationID: "Auth-A"
            ),

            // E4: Day 3 — Credit AED 400.00, value day 3
            Event(
                id: "E4",
                day: 3,
                type: .credit,
                accountID: "ACC-001",
                amount: Money(currency: aed, minorUnits: 40_000),
                valueDay: 3
            ),

            // E5: Day 4 — Settlement of Auth-A for AED 185.00
            Event(
                id: "E5",
                day: 4,
                type: .settlement,
                accountID: "ACC-001",
                amount: Money(currency: aed, minorUnits: 20_000),
                valueDay: 4,
                authorizationID: "Auth-A",
                settlementAmount: Money(currency: aed, minorUnits: 18_500)
            ),

            // E6: Day 4 — Settlement of Auth-Z (unknown auth)
            Event(
                id: "E6",
                day: 4,
                type: .settlement,
                accountID: "ACC-001",
                amount: Money(currency: aed, minorUnits: 50_000),
                valueDay: 4,
                authorizationID: "Auth-Z"
            ),

            // E7: Day 5 — Debit AED 620.00, value day 2
            Event(
                id: "E7",
                day: 5,
                type: .debit,
                accountID: "ACC-001",
                amount: Money(currency: aed, minorUnits: 62_000),
                valueDay: 2
            ),

            // E8: Day 5 — Authorization Auth-B for AED 90.00
            Event(
                id: "E8",
                day: 5,
                type: .authorization,
                accountID: "ACC-001",
                amount: Money(currency: aed, minorUnits: 9_000),
                valueDay: 5,
                authorizationID: "Auth-B"
            ),

            // E9: Day 6 — Reversal of E7
            Event(
                id: "E9",
                day: 6,
                type: .reversal,
                accountID: "ACC-001",
                amount: Money(currency: aed, minorUnits: 62_000),
                valueDay: 2,
                reversesEventID: "E7"
            ),

            // E10: Day 6 — Credit BHD 10.000 in 3 instalments, value day 6
            Event(
                id: "E10",
                day: 6,
                type: .credit,
                accountID: "ACC-002",
                amount: Money(currency: bhd, minorUnits: 10_000),
                valueDay: 6,
                instalments: 3
            ),
        ]
    }
}
