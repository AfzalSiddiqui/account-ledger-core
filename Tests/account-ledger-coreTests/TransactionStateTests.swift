//
// TransactionStateTests.swift
// account-ledger-core
//
// Created by Afzal on 28/08/2026.
//

import XCTest
@testable import account_ledger_core

final class TransactionStateTests: XCTestCase {

    func testPendingCanBePosted() {
        XCTAssertTrue(
            TransactionState.pending.canMove(to: .posted)
        )
    }

    func testPostedCanBeReversed() {
        XCTAssertTrue(
            TransactionState.posted.canMove(to: .reversed)
        )
    }

    func testPendingCannotBeReversedDirectly() {
        XCTAssertFalse(
            TransactionState.pending.canMove(to: .reversed)
        )
    }

    func testPostedCannotReturnToPending() {
        XCTAssertFalse(
            TransactionState.posted.canMove(to: .pending)
        )
    }

    func testReversedCannotChangeState() {
        XCTAssertFalse(
            TransactionState.reversed.canMove(to: .posted)
        )

        XCTAssertFalse(
            TransactionState.reversed.canMove(to: .pending)
        )
    }
}
