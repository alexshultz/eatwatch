import Foundation

public enum GoalSchedule: String, Codable, CaseIterable, Identifiable, Sendable {
    case rate
    case date

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rate: "By rate"
        case .date: "By date"
        }
    }
}

public struct EnergyPlan: Equatable, Sendable {
    public var currentTrendPounds: Double
    public var goalPounds: Double
    public var actualPoundsPerDay: Double?
    /// Desired change in the trend. Negative loses weight.
    public var desiredPoundsPerDay: Double?
    /// Calendar days from today until the trend meets the goal at the desired rate.
    /// Negative means the rate points away from the goal.
    public var daysToGoal: Double?

    public var actualKilocaloriesPerDay: Double? {
        actualPoundsPerDay.map(TrendMath.kilocalories)
    }

    public var desiredKilocaloriesPerDay: Double? {
        desiredPoundsPerDay.map(TrendMath.kilocalories)
    }

    /// How many kilocalories per day to add to the current balance.
    /// Negative means eat less than the trend says you are eating now.
    public var adjustmentKilocaloriesPerDay: Double? {
        guard let actual = actualPoundsPerDay, let desired = desiredPoundsPerDay else { return nil }
        return TrendMath.kilocalories(poundsPerDay: desired - actual)
    }

    public var isInsideGoalBand: Bool {
        abs(currentTrendPounds - goalPounds) <= TrendMath.goalBandPounds
    }

    public init(
        currentTrendPounds: Double,
        goalPounds: Double,
        actualPoundsPerDay: Double?,
        desiredPoundsPerDay: Double?,
        daysToGoal: Double?
    ) {
        self.currentTrendPounds = currentTrendPounds
        self.goalPounds = goalPounds
        self.actualPoundsPerDay = actualPoundsPerDay
        self.desiredPoundsPerDay = desiredPoundsPerDay
        self.daysToGoal = daysToGoal
    }
}

public enum PlanMath {
    public static func make(
        currentTrendPounds: Double,
        goalPounds: Double,
        actualPoundsPerDay: Double?,
        schedule: GoalSchedule,
        poundsPerWeek: Double,
        goalDay: Day,
        today: Day
    ) -> EnergyPlan {
        let desired: Double?
        let days: Double?

        switch schedule {
        case .rate:
            let perDay = poundsPerWeek / 7
            if abs(perDay) < 1e-9 {
                desired = 0
                days = nil
            } else {
                desired = perDay
                days = (goalPounds - currentTrendPounds) / perDay
            }
        case .date:
            let span = today.days(until: goalDay)
            if span <= 0 {
                desired = nil
                days = Double(span)
            } else {
                desired = (goalPounds - currentTrendPounds) / Double(span)
                days = Double(span)
            }
        }

        return EnergyPlan(
            currentTrendPounds: currentTrendPounds,
            goalPounds: goalPounds,
            actualPoundsPerDay: actualPoundsPerDay,
            desiredPoundsPerDay: desired,
            daysToGoal: days
        )
    }
}

public enum BMIBand: String, Sendable {
    case underweight = "Underweight"
    case normal = "Normal"
    case overweight = "Overweight"
    case obese = "Obese"

    public static func classify(_ bmi: Double) -> BMIBand {
        switch bmi {
        case ..<18.5: .underweight
        case ..<25: .normal
        case ..<30: .overweight
        default: .obese
        }
    }
}

public enum BodyMass {
    public static func index(pounds: Double, heightCentimeters: Double) -> Double? {
        guard heightCentimeters > 50, heightCentimeters < 280, pounds > 0 else { return nil }
        let kilograms = pounds * WeightUnit.kilogramsPerPound
        let meters = heightCentimeters / 100
        return kilograms / (meters * meters)
    }
}
