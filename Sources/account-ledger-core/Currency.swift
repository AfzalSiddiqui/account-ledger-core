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
