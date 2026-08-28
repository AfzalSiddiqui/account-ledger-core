import Foundation

struct BHDInstallmentAllocator {

    func allocate(
        total: Money,
        count: Int
    ) -> [Money] {
        precondition(total.currency == .BHD)
        precondition(count > 0)

        let base = total.minorUnits / Int64(count)
        let remainder = total.minorUnits % Int64(count)

        return (0..<count).map { index in
            Money(
                currency: .BHD,
                minorUnits: base + (index == count - 1 ? remainder : 0)
            )
        }
    }
}
