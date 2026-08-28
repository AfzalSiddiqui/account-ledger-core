//
// TransactionState.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import Foundation

enum TransactionState: Equatable {
    case pending
    case posted
    case reversed

    func canMove(to nextState: TransactionState) -> Bool {
        switch (self, nextState) {
        case (.pending, .posted):
            return true
        case (.posted, .reversed):
            return true
        default:
            return false
        }
    }
}
