import CloudKit
import Foundation
import Observation
import SwiftData

/// Opens the SwiftData store SwiftUI syncs through the private iCloud database.
@MainActor
@Observable
public final class EatWatchSession {
    public let container: ModelContainer
    public let store: LogStore
    public let settings: AppSettings
    public let health: (any HealthJournal)?
    public private(set) var healthDetail = AppName.healthReadsWeight
    public let syncsWithICloud: Bool

    private let context: ModelContext
    @ObservationIgnored private var dayResults: ResultsObserver<DayRecord, Never>?
    @ObservationIgnored private var planResults: ResultsObserver<PlanRecord, Never>?
    @ObservationIgnored private var changeWatch: ObservationTracking.Token?
    private var isAbsorbing = false
    private var absorbAgain = false

    public static func open(
        inMemory: Bool = false,
        storeURL: URL? = nil,
        seed: [WeighIn]? = nil,
        defaults: UserDefaults = .standard,
        legacyLogURL: URL? = nil,
        enableCloud: Bool = true
    ) -> EatWatchSession {
        let memory = inMemory || seed != nil
        let schema = Schema([DayRecord.self, PlanRecord.self])
        let opened = makeContainer(inMemory: memory, storeURL: storeURL, enableCloud: enableCloud && !memory, schema: schema)
        let context = opened.container.mainContext
        context.autosaveEnabled = false
        let store = LogStore(context: context)
        let settings = AppSettings(context: context, defaults: defaults)
        if let seed {
            store.importEntries(seed)
        } else if let legacyLogURL {
            store.importLegacyLog(from: legacyLogURL, defaults: defaults)
        } else if !memory, let url = try? LogStore.legacyLogURL() {
            store.importLegacyLog(from: url, defaults: defaults)
        }
        store.reload()
        settings.reload()
        let session = EatWatchSession(
            container: opened.container,
            context: context,
            store: store,
            settings: settings,
            health: makeHealthJournal(),
            syncsWithICloud: opened.syncing
        )
        session.start()
        return session
    }

    private init(
        container: ModelContainer,
        context: ModelContext,
        store: LogStore,
        settings: AppSettings,
        health: (any HealthJournal)?,
        syncsWithICloud: Bool
    ) {
        self.container = container
        self.context = context
        self.store = store
        self.settings = settings
        self.health = health
        self.syncsWithICloud = syncsWithICloud
        settings.syncState = syncsWithICloud ? .checking : .localOnly
        if let health {
            healthDetail = health.detail
        }
    }

    public func refresh() {
        absorbStoreChanges()
        Task {
            await refreshAccountStatus()
            await refreshHealth()
        }
    }

    /// Reads Health into the trend. The readings are not written to the log.
    public func refreshHealth() async {
        guard let health else {
            healthDetail = AppName.healthUnavailable
            return
        }
        await health.requestAccess()
        store.applyHealth(await health.readings())
        healthDetail = health.detail
    }

    /// Saves a weight the user entered, then writes that same entry to Health.
    public func saveEntry(_ item: WeighIn, replacing original: Day? = nil) {
        store.save(item, replacing: original)
        guard store.lastError == nil else { return }
        Task {
            if let original, original != item.day {
                await health?.deleteAuthoredSamples(on: original)
            }
            await health?.saveEntry(item)
            await refreshHealth()
        }
    }

    /// Removes an EatWatch entry. A Health sample is removed only when this app wrote it.
    public func deleteEntry(on day: Day) {
        store.delete(day)
        Task {
            await health?.deleteAuthoredSamples(on: day)
            await refreshHealth()
        }
    }

    private static func makeHealthJournal() -> (any HealthJournal)? {
        #if canImport(HealthKit)
        HealthKitJournal()
        #else
        nil
        #endif
    }

    public func refreshAccountStatus() async {
        guard syncsWithICloud else {
            settings.syncState = .localOnly
            return
        }
        do {
            let status = try await CKContainer(identifier: EatWatchCloud.containerIdentifier).accountStatus()
            switch status {
            case .available:
                settings.syncState = .syncing
            case .noAccount:
                settings.syncState = .signedOut
            case .restricted, .couldNotDetermine, .temporarilyUnavailable:
                settings.syncState = .unavailable
            @unknown default:
                settings.syncState = .unavailable
            }
        } catch {
            settings.syncState = .unavailable
        }
    }

    private func start() {
        do {
            let days = try ResultsObserver<DayRecord, Never>(modelContext: context)
            let plans = try ResultsObserver<PlanRecord, Never>(modelContext: context)
            dayResults = days
            planResults = plans
            changeWatch = withContinuousObservation(options: .didSet) { [weak self] event in
                guard let self else { return }
                _ = self.dayResults?.results
                _ = self.planResults?.results
                guard event.kind == .didSet else { return }
                self.absorbStoreChanges()
            }
        } catch {
            dayResults = nil
            planResults = nil
        }
        Task { await refreshAccountStatus() }
    }

    private func absorbStoreChanges() {
        if isAbsorbing {
            absorbAgain = true
            return
        }
        isAbsorbing = true
        repeat {
            absorbAgain = false
            context.processPendingChanges()
            store.reload()
            settings.reload()
        } while absorbAgain
        isAbsorbing = false
    }

    private static func makeContainer(
        inMemory: Bool,
        storeURL: URL?,
        enableCloud: Bool,
        schema: Schema
    ) -> (container: ModelContainer, syncing: Bool) {
        if inMemory {
            let configuration = ModelConfiguration(
                storeName,
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return (open(schema: schema, configuration: configuration), false)
        }

        let url = storeURL ?? (try? LogStore.storeURL()) ?? URL.temporaryDirectory.appending(path: "\(storeName).store")
        if enableCloud {
            let cloud = ModelConfiguration(
                storeName,
                schema: schema,
                url: url,
                cloudKitDatabase: .private(EatWatchCloud.containerIdentifier)
            )
            if let container = try? ModelContainer(for: schema, configurations: [cloud]) {
                return (container, true)
            }
        }
        let local = ModelConfiguration(
            storeName,
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        return (open(schema: schema, configuration: local), false)
    }

    private static func open(schema: Schema, configuration: ModelConfiguration) -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("\(AppName.display) could not open its log. \(error.localizedDescription)")
        }
    }

    /// SwiftData and CloudKit identity. Independent of the name people see.
    private static let storeName = "EatWatch"
}
