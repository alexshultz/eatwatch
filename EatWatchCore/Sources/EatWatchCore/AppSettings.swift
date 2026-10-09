import Foundation
import Observation
import SwiftData

@MainActor
@Observable
public final class AppSettings {
    public var weightUnit: WeightUnit {
        didSet { persistPlan() }
    }

    public var energyUnit: EnergyUnit {
        didSet { persistPlan() }
    }

    public var goalPounds: Double? {
        didSet { persistPlan() }
    }

    public var goalSchedule: GoalSchedule {
        didSet { persistPlan() }
    }

    /// Negative loses weight. Stored in pounds per week.
    public var goalPoundsPerWeek: Double {
        didSet { persistPlan() }
    }

    public var goalDate: Date {
        didSet { persistPlan() }
    }

    public var heightCentimeters: Double? {
        didSet { persistPlan() }
    }

    /// Stays on this device. A lock is not part of the shared log.
    public var locksWithBiometrics: Bool {
        didSet { defaults.set(locksWithBiometrics, forKey: Key.lock) }
    }

    public var syncState: ICloudSyncState = .checking
    public private(set) var lastError: String?

    private let context: ModelContext
    private let defaults: UserDefaults
    private var isApplying = false

    public init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.defaults = defaults
        weightUnit = .pounds
        energyUnit = .kilocalories
        goalPounds = nil
        goalSchedule = .rate
        goalPoundsPerWeek = -1
        goalDate = Day.gregorian.date(byAdding: .day, value: 90, to: .now) ?? .now
        heightCentimeters = nil
        locksWithBiometrics = defaults.bool(forKey: Key.lock)
        if PlanRecord.keeper(in: context) == nil {
            let record = PlanRecord()
            copyDefaults(into: record)
            record.modifiedAt = .distantPast
            context.insert(record)
            try? context.save()
        }
        reload()
    }

    public var goalDay: Day { Day(date: goalDate) }

    /// Weekly goal rate in the unit the plan editor shows. Stone mode edits pounds.
    public var displayedWeeklyRate: Double {
        get {
            let unit: WeightUnit = weightUnit == .stones ? .pounds : weightUnit
            return unit.fromPounds(goalPoundsPerWeek)
        }
        set {
            let unit: WeightUnit = weightUnit == .stones ? .pounds : weightUnit
            goalPoundsPerWeek = unit.toPounds(newValue)
        }
    }

    public func reload() {
        guard let record = PlanRecord.keeper(in: context) else { return }
        isApplying = true
        let unit = WeightUnit(rawValue: record.weightUnitRaw) ?? .pounds
        if weightUnit != unit { weightUnit = unit }
        let energy = EnergyUnit(rawValue: record.energyUnitRaw) ?? .kilocalories
        if energyUnit != energy { energyUnit = energy }
        if goalPounds != record.goalPounds { goalPounds = record.goalPounds }
        let schedule = GoalSchedule(rawValue: record.goalScheduleRaw) ?? .rate
        if goalSchedule != schedule { goalSchedule = schedule }
        if goalPoundsPerWeek != record.goalPoundsPerWeek { goalPoundsPerWeek = record.goalPoundsPerWeek }
        if goalDate != record.goalDate { goalDate = record.goalDate }
        if heightCentimeters != record.heightCentimeters { heightCentimeters = record.heightCentimeters }
        isApplying = false
    }

    private func persistPlan() {
        guard !isApplying else { return }
        let record = PlanRecord.keeper(in: context) ?? PlanRecord()
        if record.modelContext == nil {
            context.insert(record)
        }
        record.weightUnitRaw = weightUnit.rawValue
        record.energyUnitRaw = energyUnit.rawValue
        record.goalPounds = goalPounds
        record.goalScheduleRaw = goalSchedule.rawValue
        record.goalPoundsPerWeek = goalPoundsPerWeek
        record.goalDate = goalDate
        record.heightCentimeters = heightCentimeters
        record.modifiedAt = .now
        do {
            try context.save()
            lastError = nil
        } catch {
            lastError = "The plan could not be saved. \(error.localizedDescription)"
        }
    }

    private func copyDefaults(into record: PlanRecord) {
        if let raw = defaults.string(forKey: Key.weightUnit), WeightUnit(rawValue: raw) != nil {
            record.weightUnitRaw = raw
        }
        if let raw = defaults.string(forKey: Key.energyUnit), EnergyUnit(rawValue: raw) != nil {
            record.energyUnitRaw = raw
        }
        if defaults.object(forKey: Key.goal) != nil {
            record.goalPounds = defaults.double(forKey: Key.goal)
        }
        if let raw = defaults.string(forKey: Key.schedule), GoalSchedule(rawValue: raw) != nil {
            record.goalScheduleRaw = raw
        }
        if defaults.object(forKey: Key.rate) != nil {
            record.goalPoundsPerWeek = defaults.double(forKey: Key.rate)
        }
        if defaults.object(forKey: Key.goalDate) != nil {
            record.goalDate = Date(timeIntervalSince1970: defaults.double(forKey: Key.goalDate))
        } else {
            record.goalDate = Day.gregorian.date(byAdding: .day, value: 90, to: .now) ?? .now
        }
        if defaults.object(forKey: Key.height) != nil {
            record.heightCentimeters = defaults.double(forKey: Key.height)
        }
    }

    private enum Key {
        static let weightUnit = "eatwatch.weightUnit"
        static let energyUnit = "eatwatch.energyUnit"
        static let goal = "eatwatch.goalPounds"
        static let schedule = "eatwatch.goalSchedule"
        static let rate = "eatwatch.poundsPerWeek"
        static let goalDate = "eatwatch.goalDate"
        static let height = "eatwatch.heightCm"
        static let lock = "eatwatch.lock"
    }
}
