import Foundation

/// The weight trend from John Walker's *The Hacker's Diet*.
///
/// Each weigh-in moves the trend by 10% of the gap between the scale and the
/// previous trend. A day with no weight leaves the trend where it is.
/// One pound of trend is 3,500 kilocalories.
public enum TrendMath {
    public static let dailyShare = 0.1
    public static let kilocaloriesPerPound = 3500.0
    public static let kilojoulesPerKilocalorie = 4.184
    public static let goalBandPounds = 2.5
    public static let minimumSlopeCount = 4

    public static func nextTrend(previous: Double?, weight: Double) -> Double {
        guard let previous else { return weight }
        return previous + dailyShare * (weight - previous)
    }

    public static func kilocalories(poundsPerDay: Double) -> Double {
        poundsPerDay * kilocaloriesPerPound
    }
}

public struct Analysis: Equatable, Sendable {
    public var weighed: [TrendPoint]
    public var daily: [DailyPoint]

    public static let empty = Analysis(weighed: [], daily: [])

    public init(weighed: [TrendPoint], daily: [DailyPoint]) {
        self.weighed = weighed
        self.daily = daily
    }

    public var latest: TrendPoint? { weighed.last }

    public func point(on day: Day) -> TrendPoint? {
        weighed.first { $0.day == day }
    }

    /// Least-squares slope of the trend, in pounds per calendar day.
    /// Needs four weigh-ins in the window. Gaps count as time.
    /// The 30-day slope when there are enough weigh-ins, otherwise 90 days, otherwise the whole log.
    public func preferredSlope(today: Day = .today()) -> (title: String, poundsPerDay: Double)? {
        let windows: [(String, Int?)] = [("the last 30 days", 30), ("the last 90 days", 90), ("the whole log", nil)]
        guard let first = weighed.first?.day else { return nil }
        for (title, length) in windows {
            let start = length.map { today.adding(days: -($0 - 1)) } ?? first
            if let poundsPerDay = slope(from: max(start, first), through: today) {
                return (title, poundsPerDay)
            }
        }
        return nil
    }

    public func slope(from start: Day, through end: Day) -> Double? {
        let slice = weighed.filter { $0.day >= start && $0.day <= end }
        guard slice.count >= TrendMath.minimumSlopeCount else { return nil }
        let origin = slice[0].day
        let xs = slice.map { Double(origin.days(until: $0.day)) }
        let ys = slice.map(\.trendPounds)
        return LinearFit.slope(xs: xs, ys: ys)
    }
}

enum LinearFit {
    static func slope(xs: [Double], ys: [Double]) -> Double? {
        guard xs.count == ys.count, xs.count >= 2 else { return nil }
        let count = Double(xs.count)
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXX = xs.reduce(0) { $0 + $1 * $1 }
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sxx = sumXX - sumX * sumX / count
        guard abs(sxx) > 1e-12 else { return nil }
        let sxy = sumXY - sumX * sumY / count
        return sxy / sxx
    }
}

public enum TrendEngine {
    public static func analyze(_ entries: [WeighIn], through end: Day? = nil) -> Analysis {
        let sorted = entries
            .filter { WeightInput.isPlausible($0.weightPounds) }
            .sorted { $0.day < $1.day }
        guard let first = sorted.first else { return .empty }

        let lastDay = end.map { max($0, sorted[sorted.count - 1].day) } ?? sorted[sorted.count - 1].day
        var weighed: [TrendPoint] = []
        var daily: [DailyPoint] = []
        var weightTrend: Double?
        var index = 0
        var cursor = first.day

        while cursor <= lastDay {
            if index < sorted.count, sorted[index].day == cursor {
                let entry = sorted[index]
                let trend = TrendMath.nextTrend(previous: weightTrend, weight: entry.weightPounds)
                weightTrend = trend
                weighed.append(TrendPoint(
                    day: entry.day,
                    weightPounds: entry.weightPounds,
                    trendPounds: trend,
                    rung: entry.rung,
                    flagged: entry.flagged,
                    note: entry.note
                ))
                daily.append(DailyPoint(day: cursor, trendPounds: trend, weightPounds: entry.weightPounds))
                index += 1
            } else if let weightTrend {
                daily.append(DailyPoint(day: cursor, trendPounds: weightTrend, weightPounds: nil))
            }
            if cursor == lastDay { break }
            let next = cursor.adding(days: 1)
            if next <= cursor { break }
            cursor = next
        }

        return Analysis(weighed: weighed, daily: daily)
    }
}
