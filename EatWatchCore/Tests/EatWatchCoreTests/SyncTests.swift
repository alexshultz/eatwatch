import XCTest
import SwiftData
@testable import EatWatchCore

@MainActor
final class SyncTests: XCTestCase {
    func testSaveDeleteAndImportKeepOtherDays() {
        let session = EatWatchSession.open(inMemory: true, defaults: freshDefaults(), enableCloud: false)
        let monday = Day(year: 2024, month: 5, day: 6)
        let tuesday = Day(year: 2024, month: 5, day: 7)
        session.store.save(WeighIn(day: monday, weightPounds: 180, note: "quiet"))
        session.store.save(WeighIn(day: tuesday, weightPounds: 181))
        XCTAssertEqual(session.store.count, 2)
        XCTAssertEqual(session.store.weighIn(on: monday)?.note, "quiet")

        let replaced = session.store.importEntries([
            WeighIn(day: monday, weightPounds: 179, note: "imported")
        ])
        XCTAssertEqual(replaced, 1)
        XCTAssertEqual(session.store.count, 2)
        XCTAssertEqual(session.store.weighIn(on: monday)?.weightPounds, 179)
        XCTAssertEqual(session.store.weighIn(on: tuesday)?.weightPounds, 181)

        session.store.delete(tuesday)
        XCTAssertNil(session.store.weighIn(on: tuesday))
        XCTAssertEqual(session.store.count, 1)
    }

    func testDuplicateDaysKeepTheNewerEdit() throws {
        let session = EatWatchSession.open(inMemory: true, defaults: freshDefaults(), enableCloud: false)
        let day = Day(year: 2024, month: 6, day: 1)
        session.store.save(WeighIn(day: day, weightPounds: 170))
        session.container.mainContext.insert(
            DayRecord(
                dayISO: day.iso,
                weightPounds: 165,
                note: "older",
                modifiedAt: Date(timeIntervalSince1970: 10)
            )
        )
        try session.container.mainContext.save()
        session.store.reload()
        XCTAssertEqual(session.store.count, 1)
        XCTAssertEqual(session.store.weighIn(on: day)?.weightPounds, 170)
        let records = try session.container.mainContext.fetch(FetchDescriptor<DayRecord>())
        XCTAssertEqual(records.count, 1)
    }

    func testLegacyImportRunsOnceAndDoesNotRestoreADeletedDay() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let logURL = folder.appending(path: "log.json")
        let day = Day(year: 2023, month: 4, day: 2)
        let file = LogFile(entries: [WeighIn(day: day, weightPounds: 200, note: "from json")])
        let data = try JSONEncoder().encode(file)
        try data.write(to: logURL, options: .atomic)
        let defaults = freshDefaults()
        let storeURL = folder.appending(path: "EatWatch.store")

        let session = EatWatchSession.open(
            storeURL: storeURL,
            defaults: defaults,
            legacyLogURL: logURL,
            enableCloud: false
        )
        XCTAssertEqual(session.store.weighIn(on: day)?.weightPounds, 200)
        session.store.delete(day)
        XCTAssertEqual(session.store.count, 0)

        session.store.importLegacyLog(from: logURL, defaults: defaults)
        XCTAssertEqual(session.store.count, 0)
    }

    func testSettingsRoundTripAndStayOffTheLockKey() {
        let defaults = freshDefaults()
        defaults.set(true, forKey: "eatwatch.lock")
        defaults.set(175.0, forKey: "eatwatch.goalPounds")
        defaults.set("kilograms", forKey: "eatwatch.weightUnit")
        let session = EatWatchSession.open(inMemory: true, defaults: defaults, enableCloud: false)
        XCTAssertTrue(session.settings.locksWithBiometrics)
        XCTAssertEqual(session.settings.goalPounds, 175)
        XCTAssertEqual(session.settings.weightUnit, .kilograms)

        session.settings.goalPoundsPerWeek = -0.5
        session.settings.locksWithBiometrics = false
        session.settings.reload()
        XCTAssertEqual(session.settings.goalPoundsPerWeek, -0.5)
        XCTAssertFalse(session.settings.locksWithBiometrics)

        let records = try? session.container.mainContext.fetch(FetchDescriptor<PlanRecord>())
        XCTAssertEqual(records?.count, 1)
        XCTAssertEqual(records?.first?.goalPoundsPerWeek, -0.5)
    }

    func testADirectSaveShowsUpWithoutAnotherReload() async throws {
        let session = EatWatchSession.open(inMemory: true, defaults: freshDefaults(), enableCloud: false)
        let day = Day(year: 2024, month: 8, day: 9)
        session.container.mainContext.insert(
            DayRecord(dayISO: day.iso, weightPounds: 166, modifiedAt: .now)
        )
        try session.container.mainContext.save()
        for _ in 0..<5 {
            if session.store.weighIn(on: day)?.weightPounds == 166 { break }
            await Task.yield()
        }
        XCTAssertEqual(session.store.weighIn(on: day)?.weightPounds, 166)
    }

    func testNewerPlanWins() throws {
        let session = EatWatchSession.open(inMemory: true, defaults: freshDefaults(), enableCloud: false)
        session.settings.goalPounds = 160
        let older = PlanRecord()
        older.goalPounds = 140
        older.modifiedAt = Date(timeIntervalSince1970: 50)
        session.container.mainContext.insert(older)
        try session.container.mainContext.save()
        session.settings.reload()
        XCTAssertEqual(session.settings.goalPounds, 160)
        let records = try session.container.mainContext.fetch(FetchDescriptor<PlanRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.goalPounds, 160)
    }

    private func freshDefaults() -> UserDefaults {
        let name = "EatWatchTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
