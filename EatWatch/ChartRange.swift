import Foundation

enum ChartRange: String, CaseIterable, Identifiable {
    case month = "Month"
    case quarter = "Quarter"
    case year = "Year"
    case all = "All"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .month: 31
        case .quarter: 92
        case .year: 366
        case .all: nil
        }
    }
}
