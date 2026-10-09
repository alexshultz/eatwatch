import Foundation

public struct WeighIn: Hashable, Codable, Identifiable, Sendable {
    public var day: Day
    public var weightPounds: Double
    public var rung: Int?
    public var flagged: Bool
    public var note: String

    public var id: Day { day }

    public init(
        day: Day,
        weightPounds: Double,
        rung: Int? = nil,
        flagged: Bool = false,
        note: String = ""
    ) {
        self.day = day
        self.weightPounds = weightPounds
        self.rung = ExerciseRung.accepted(rung)
        self.flagged = flagged
        self.note = note
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(Day.self, forKey: .day)
        weightPounds = try container.decode(Double.self, forKey: .weightPounds)
        rung = ExerciseRung.accepted(try container.decodeIfPresent(Int.self, forKey: .rung))
        flagged = try container.decodeIfPresent(Bool.self, forKey: .flagged) ?? false
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

public struct TrendPoint: Hashable, Identifiable, Sendable {
    public var day: Day
    public var weightPounds: Double
    public var trendPounds: Double
    public var rung: Int?
    public var flagged: Bool
    public var note: String

    public var id: Day { day }
    public var variancePounds: Double { weightPounds - trendPounds }

    public init(
        day: Day,
        weightPounds: Double,
        trendPounds: Double,
        rung: Int? = nil,
        flagged: Bool = false,
        note: String = ""
    ) {
        self.day = day
        self.weightPounds = weightPounds
        self.trendPounds = trendPounds
        self.rung = rung
        self.flagged = flagged
        self.note = note
    }
}

public struct DailyPoint: Hashable, Identifiable, Sendable {
    public var day: Day
    public var trendPounds: Double
    public var weightPounds: Double?

    public var id: Day { day }

    public init(day: Day, trendPounds: Double, weightPounds: Double?) {
        self.day = day
        self.trendPounds = trendPounds
        self.weightPounds = weightPounds
    }
}
