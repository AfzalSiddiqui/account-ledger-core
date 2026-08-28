//
// Currency.swift
// account-ledger-core
//
// Created by Afzal on 27/08/2026.
//

import Foundation

enum Currency: String {
    case AED
    case BHD

    var scale: Int {
        switch self {
        case .AED:
            return 2
        case .BHD:
            return 3
        }
    }
}
