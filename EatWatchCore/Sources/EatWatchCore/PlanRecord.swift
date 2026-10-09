import Foundation
import SwiftData

/// The goal, units, and height that follow the iCloud account.
/// The device lock is not stored here.
@Model
public final class PlanRecord {
    public var weightUnitRaw: String = WeightUnit.pounds.rawValue
    public var energyUnitRaw: String = EnergyUnit.kilocalories.rawValue
    public var goalPounds: Double? = nil
    public var goalScheduleRaw: String = GoalSchedule.rate.rawValue
    public var goalPoundsPerWeek: Double = -1
    public var goalDate: Date = Date.distantFuture
    public var heightCentimeters: Double? = nil
    public var modifiedAt: Date = Date.distantPast

    public init() {}

    /// Keeps the record a person has actually edited. Untouched copies lose to that one.
    @MainActor
    public static func keeper(in context: ModelContext) -> PlanRecord? {
        let records = (try? context.fetch(FetchDescriptor<PlanRecord>())) ?? []
        guard let winner = records.sorted(by: prefer).first else { return nil }
        var removed = false
        for extra in records where extra !== winner {
            context.delete(extra)
            removed = true
        }
        if removed {
            try? context.save()
        }
        return winner
    }

    private static func prefer(_ lhs: PlanRecord, _ rhs: PlanRecord) -> Bool {
        if lhs.modifiedAt != rhs.modifiedAt {
            return lhs.modifiedAt > rhs.modifiedAt
        }
        let leftScore = (lhs.goalPounds == nil ? 0 : 2) + (lhs.heightCentimeters == nil ? 0 : 1)
        let rightScore = (rhs.goalPounds == nil ? 0 : 2) + (rhs.heightCentimeters == nil ? 0 : 1)
        if leftScore != rightScore {
            return leftScore > rightScore
        }
        return String(describing: lhs.persistentModelID) > String(describing: rhs.persistentModelID)
    }
}
