import Foundation

/// One calendar day's weight, read from Health and kept only in memory.
public struct HealthDayReading: Equatable, Sendable {
    public var day: Day
    public var weightPounds: Double?

    public init(day: Day, weightPounds: Double? = nil) {
        self.day = day
        self.weightPounds = weightPounds
    }
}

/// Builds the series the trend uses. Health supplies the weight for a day.
/// A Health reading is never written into the log.
public enum HealthLogMerge {
    public static func entries(log: [Day: WeighIn], health: [HealthDayReading]) -> [WeighIn] {
        var result = log
        for reading in health {
            guard let weight = plausibleWeight(reading.weightPounds) else { continue }
            if var existing = result[reading.day] {
                existing.weightPounds = weight
                result[reading.day] = existing
            } else {
                result[reading.day] = WeighIn(day: reading.day, weightPounds: weight)
            }
        }
        return result.values.sorted { $0.day < $1.day }
    }

    private static func plausibleWeight(_ pounds: Double?) -> Double? {
        guard let pounds, WeightInput.isPlausible(pounds) else { return nil }
        return pounds
    }
}

/// Reads Health for the trend and writes a weight the user entered.
@MainActor
public protocol HealthJournal: AnyObject {
    var detail: String { get }
    func requestAccess() async
    func readings() async -> [HealthDayReading]
    func saveEntry(_ item: WeighIn) async
    func deleteAuthoredSamples(on day: Day) async
}
