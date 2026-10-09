import Foundation

/// A calendar day in the Gregorian calendar, with no time and no time zone.
public struct Day: Hashable, Codable, Comparable, Identifiable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public var id: String { iso }

    public var iso: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init?(iso: String) {
        let parts = iso.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month),
              (1...31).contains(day) else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    public init(date: Date, calendar: Calendar = Day.gregorian) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? 1
        month = parts.month ?? 1
        day = parts.day ?? 1
    }

    public static func today(calendar: Calendar = Day.gregorian) -> Day {
        Day(date: Date(), calendar: calendar)
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Noon on this day, so a daylight-saving shift cannot move the calendar date.
    public func date(calendar: Calendar = Day.gregorian) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
            ?? Date(timeIntervalSince1970: 0)
    }

    public func adding(days: Int, calendar: Calendar = Day.gregorian) -> Day {
        let shifted = calendar.date(byAdding: .day, value: days, to: date(calendar: calendar))
            ?? date(calendar: calendar)
        return Day(date: shifted, calendar: calendar)
    }

    public func days(until other: Day, calendar: Calendar = Day.gregorian) -> Int {
        calendar.dateComponents([.day], from: date(calendar: calendar), to: other.date(calendar: calendar)).day
            ?? 0
    }

    public func formatted(date style: Date.FormatStyle.DateStyle = .abbreviated) -> String {
        date().formatted(date: style, time: .omitted)
    }

    public var monthTitle: String {
        date().formatted(.dateTime.month(.wide).year())
    }

    public var longDate: String {
        date().formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }
}
