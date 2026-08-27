import XCTest
@testable import account_ledger_core

final class MoneyTests: XCTestCase {

    func testAEDStoresMinorUnitsExactly() {
        let amount = Money(currency: .AED, minorUnits: 120000)

        XCTAssertEqual(amount.minorUnits, 120000)
        XCTAssertEqual(amount.description, "1200.00 AED")
    }

    func testBHDStoresThreeDecimalPlaces() {
        let amount = Money(currency: .BHD, minorUnits: 10000)

        XCTAssertEqual(amount.minorUnits, 10000)
        XCTAssertEqual(amount.description, "10.000 BHD")
    }

    func testMoneySubtraction() {
        let balance = Money(currency: .AED, minorUnits: 120000)
            .subtracting(Money(currency: .AED, minorUnits: 95000))

        XCTAssertEqual(balance.minorUnits, 25000)
        XCTAssertEqual(balance.description, "250.00 AED")
    }

    func testNegativeBalance() {
        let balance = Money(currency: .AED, minorUnits: -37000)

        XCTAssertEqual(balance.description, "-370.00 AED")
    }
}
