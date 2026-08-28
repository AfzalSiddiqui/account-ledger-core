//
// Idempotency.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import Foundation

struct IdempotencyStore {

    private(set) var processedTransactionIDs: Set<String> = []

    mutating func checkAndRecord(transactionID: String) -> Bool {
        guard !processedTransactionIDs.contains(transactionID) else {
            return false
        }

        processedTransactionIDs.insert(transactionID)
        return true
    }
}
