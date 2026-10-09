import Foundation
import SwiftData

/// One morning in the private iCloud database. The day string is the identity.
@Model
public final class DayRecord {
    public var dayISO: String = ""
    public var weightPounds: Double = 0
    public var rung: Int? = nil
    public var flagged: Bool = false
    public var note: String = ""
    public var modifiedAt: Date = Date.distantPast

    public init(
        dayISO: String,
        weightPounds: Double,
        rung: Int? = nil,
        flagged: Bool = false,
        note: String = "",
        modifiedAt: Date = .now
    ) {
        self.dayISO = dayISO
        self.weightPounds = weightPounds
        self.rung = ExerciseRung.accepted(rung)
        self.flagged = flagged
        self.note = note
        self.modifiedAt = modifiedAt
    }

    public var weighIn: WeighIn? {
        guard let day = Day(iso: dayISO), WeightInput.isPlausible(weightPounds) else { return nil }
        return WeighIn(day: day, weightPounds: weightPounds, rung: rung, flagged: flagged, note: note)
    }

    /// CloudKit cannot enforce one record per day, so keep the newest edit and drop the rest.
    @MainActor
    public static func reconcile(in context: ModelContext) -> Bool {
        let records = (try? context.fetch(FetchDescriptor<DayRecord>())) ?? []
        let groups = Dictionary(grouping: records, by: \.dayISO)
        var removed = false
        for group in groups.values where group.count > 1 {
            let ranked = group.sorted { prefer($0, over: $1) }
            for extra in ranked.dropFirst() {
                context.delete(extra)
                removed = true
            }
        }
        return removed
    }

    private static func prefer(_ lhs: DayRecord, over rhs: DayRecord) -> Bool {
        if lhs.modifiedAt != rhs.modifiedAt {
            return lhs.modifiedAt > rhs.modifiedAt
        }
        return String(describing: lhs.persistentModelID) > String(describing: rhs.persistentModelID)
    }
}
