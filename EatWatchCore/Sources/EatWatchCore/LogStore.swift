import Foundation
import Observation
import SwiftData

public struct LogFile: Codable, Equatable, Sendable {
    public var version: Int
    public var entries: [WeighIn]

    public init(version: Int = 1, entries: [WeighIn]) {
        self.version = version
        self.entries = entries
    }
}

@MainActor
@Observable
public final class LogStore {
    public private(set) var analysis: Analysis = .empty
    public private(set) var lastError: String?
    public private(set) var changeCount = 0

    private var entries: [Day: WeighIn] = [:]
    private var healthReadings: [HealthDayReading] = []
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
        reload()
    }

    public func weighIn(on day: Day) -> WeighIn? {
        entries[day]
    }

    public var count: Int { entries.count }

    public func save(_ item: WeighIn, replacing original: Day? = nil) {
        guard WeightInput.isPlausible(item.weightPounds) else {
            lastError = "Enter a weight above zero."
            return
        }
        if let original, original != item.day {
            removeRecord(on: original)
        }
        var stored = item
        stored.note = String(item.note.prefix(500))
        upsert(stored, modifiedAt: .now)
        lastError = nil
        rebuild(save: true)
    }

    public func delete(_ day: Day) {
        removeRecord(on: day)
        rebuild(save: true)
    }

    public func deleteAll() {
        let records = (try? context.fetch(FetchDescriptor<DayRecord>())) ?? []
        for record in records {
            context.delete(record)
        }
        rebuild(save: true)
    }

    /// Returns how many of the imported days replaced a weight already in the log.
    /// Days missing from the file stay in the log.
    @discardableResult
    public func importEntries(_ items: [WeighIn]) -> Int {
        var replaced = 0
        for item in items where WeightInput.isPlausible(item.weightPounds) {
            if entries[item.day] != nil { replaced += 1 }
            var stored = item
            stored.note = String(item.note.prefix(500))
            upsert(stored, modifiedAt: .now)
        }
        rebuild(save: true)
        return replaced
    }

    /// Fills days the store does not have yet from a version-1 JSON log. Runs once per defaults suite.
    public func importLegacyLog(from url: URL, defaults: UserDefaults) {
        guard defaults.bool(forKey: Key.imported) == false else { return }
        let exists = FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
        guard exists else {
            defaults.set(true, forKey: Key.imported)
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(LogFile.self, from: data)
            guard file.version <= 1 else {
                lastError = "This log was written by a newer version of \(AppName.display)."
                return
            }
            let stamp = fileDate(url)
            reload()
            for item in file.entries where WeightInput.isPlausible(item.weightPounds) && entries[item.day] == nil {
                upsert(item, modifiedAt: stamp)
            }
            defaults.set(true, forKey: Key.imported)
            rebuild(save: true)
        } catch {
            lastError = "The saved log could not be read. \(error.localizedDescription)"
        }
    }

    /// Uses Health readings for the trend. Nothing is written to the log.
    public func applyHealth(_ readings: [HealthDayReading]) {
        healthReadings = readings
        publishAnalysis()
    }

    public func reload() {
        context.processPendingChanges()
        let removed = DayRecord.reconcile(in: context)
        let records = (try? context.fetch(FetchDescriptor<DayRecord>())) ?? []
        entries = Self.map(records.compactMap(\.weighIn))
        publishAnalysis()
        guard removed else { return }
        do {
            try context.save()
        } catch {
            lastError = "The log could not be saved. \(error.localizedDescription)"
        }
    }

    public static func legacyLogURL() throws -> URL {
        let folder = URL.applicationSupportDirectory.appending(path: storeFolderName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "log.json")
    }

    public static func storeURL() throws -> URL {
        let folder = URL.applicationSupportDirectory.appending(path: storeFolderName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "\(storeFolderName).store")
    }

    /// On-disk identity of the log. This stays put when the display name changes.
    private static let storeFolderName = "EatWatch"

    private func upsert(_ item: WeighIn, modifiedAt: Date) {
        if let record = record(on: item.day) {
            record.weightPounds = item.weightPounds
            record.rung = item.rung
            record.flagged = item.flagged
            record.note = item.note
            record.modifiedAt = modifiedAt
        } else {
            context.insert(
                DayRecord(
                    dayISO: item.day.iso,
                    weightPounds: item.weightPounds,
                    rung: item.rung,
                    flagged: item.flagged,
                    note: item.note,
                    modifiedAt: modifiedAt
                )
            )
        }
        entries[item.day] = item
    }

    private func removeRecord(on day: Day) {
        if let record = record(on: day) {
            context.delete(record)
        }
        entries.removeValue(forKey: day)
    }

    private func record(on day: Day) -> DayRecord? {
        let iso = day.iso
        let records = (try? context.fetch(FetchDescriptor<DayRecord>())) ?? []
        return records.filter { $0.dayISO == iso }.sorted { $0.modifiedAt > $1.modifiedAt }.first
    }

    private func rebuild(save shouldSave: Bool) {
        _ = DayRecord.reconcile(in: context)
        let records = (try? context.fetch(FetchDescriptor<DayRecord>())) ?? []
        entries = Self.map(records.compactMap(\.weighIn))
        publishAnalysis()
        guard shouldSave else { return }
        do {
            try context.save()
        } catch {
            lastError = "The log could not be saved. \(error.localizedDescription)"
        }
    }

    private func publishAnalysis() {
        let list = HealthLogMerge.entries(log: entries, health: healthReadings)
        if list.isEmpty {
            analysis = .empty
        } else {
            let end = max(list[list.count - 1].day, .today())
            analysis = TrendEngine.analyze(list, through: end)
        }
        changeCount += 1
    }

    private func fileDate(_ url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? .distantPast
    }

    private static func map(_ items: [WeighIn]) -> [Day: WeighIn] {
        var result: [Day: WeighIn] = [:]
        for item in items where WeightInput.isPlausible(item.weightPounds) {
            result[item.day] = item
        }
        return result
    }

    private enum Key {
        static let imported = "eatwatch.didImportJSONLog"
    }
}
