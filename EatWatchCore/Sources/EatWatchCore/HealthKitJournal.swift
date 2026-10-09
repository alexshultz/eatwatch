#if canImport(HealthKit)
import Foundation
import HealthKit
#if os(macOS)
import Security
#endif

/// HealthKit access for body mass.
///
/// Readings stay in memory. A sample is written only for a weight the user
/// entered here, and a delete removes only samples this app wrote.
@MainActor
public final class HealthKitJournal: HealthJournal {
    public private(set) var detail = AppName.healthReadsWeight

    private let store = HKHealthStore()
    private let bodyMass = HKQuantityType(.bodyMass)
    private let pounds = HKUnit.pound()

    public init() {}

    public func requestAccess() async {
        guard signedForHealth else {
            detail = AppName.healthUnsigned
            return
        }
        guard HKHealthStore.isHealthDataAvailable() else {
            detail = AppName.healthUnavailable
            return
        }
        do {
            try await store.requestAuthorization(toShare: [bodyMass], read: [bodyMass])
            detail = AppName.healthCanSaveWeight
        } catch {
            detail = AppName.healthRequestFailed
        }
    }

    public func readings() async -> [HealthDayReading] {
        guard signedForHealth, HKHealthStore.isHealthDataAvailable() else { return [] }
        let weights = (try? await quantities(of: bodyMass)) ?? []
        var byDay: [Day: HealthDayReading] = [:]
        for sample in weights {
            let day = Day(date: sample.startDate)
            guard byDay[day]?.weightPounds == nil else { continue }
            var reading = byDay[day] ?? HealthDayReading(day: day)
            reading.weightPounds = sample.quantity.doubleValue(for: pounds)
            byDay[day] = reading
        }
        return byDay.values.sorted { $0.day < $1.day }
    }

    public func saveEntry(_ item: WeighIn) async {
        guard signedForHealth, HKHealthStore.isHealthDataAvailable() else { return }
        guard store.authorizationStatus(for: bodyMass) == .sharingAuthorized else { return }
        await deleteAuthoredSamples(on: item.day)
        let moment = item.day.date()
        let sample = HKQuantitySample(
            type: bodyMass,
            quantity: HKQuantity(unit: pounds, doubleValue: item.weightPounds),
            start: moment,
            end: moment,
            metadata: [HKMetadataKeyWasUserEntered: true]
        )
        try? await store.save(sample)
    }

    public func deleteAuthoredSamples(on day: Day) async {
        guard signedForHealth, HKHealthStore.isHealthDataAvailable() else { return }
        guard store.authorizationStatus(for: bodyMass) == .sharingAuthorized else { return }
        let samples = (try? await quantities(of: bodyMass, predicate: authored(on: day))) ?? []
        if samples.isEmpty { return }
        try? await store.delete(samples)
    }

    private func quantities(
        of type: HKQuantityType,
        predicate: NSPredicate? = nil
    ) async throws -> [HKQuantitySample] {
        let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: predicate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [samplePredicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        return try await descriptor.result(for: store)
    }

    /// The Mac profile cannot carry HealthKit. Skip the calls unless this binary is signed for it.
    private var signedForHealth: Bool {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        return SecTaskCopyValueForEntitlement(task, "com.apple.developer.healthkit" as CFString, nil) != nil
        #else
        return true
        #endif
    }

    /// Samples this app wrote on that calendar day. Other sources are left alone.
    private func authored(on day: Day) -> NSPredicate {
        let calendar = Day.gregorian
        let start = calendar.startOfDay(for: day.date(calendar: calendar))
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let dates = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let source = HKQuery.predicateForObjects(from: HKSource.default())
        return NSCompoundPredicate(andPredicateWithSubpredicates: [dates, source])
    }
}
#endif
