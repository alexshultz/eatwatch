import XCTest
import SwiftData
@testable import EatWatchCore

final class HealthLogTests: XCTestCase {
    func testHealthDayIsUsedAndNotRequiredToAlreadyBeInTheLog() {
        let healthDay = Day(year: 2024, month: 1, day: 2)
        let logDay = Day(year: 2024, month: 1, day: 1)
        let merged = HealthLogMerge.entries(
            log: [logDay: WeighIn(day: logDay, weightPounds: 180, note: "logged")],
            health: [HealthDayReading(day: healthDay, weightPounds: 181)]
        )
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[1].weightPounds, 181)
        XCTAssertEqual(merged[1].note, "")
    }

    func testSameDayKeepsTheLogAndUsesTheHealthWeight() {
        let day = Day(year: 2024, month: 3, day: 4)
        let merged = HealthLogMerge.entries(
            log: [day: WeighIn(day: day, weightPounds: 200, rung: 4, flagged: true, note: "morning")],
            health: [HealthDayReading(day: day, weightPounds: 190)]
        )
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].weightPounds, 190)
        XCTAssertEqual(merged[0].rung, 4)
        XCTAssertTrue(merged[0].flagged)
        XCTAssertEqual(merged[0].note, "morning")
    }

    func testAReadingWithoutAWeightDoesNotCreateADay() {
        let day = Day(year: 2024, month: 5, day: 1)
        let merged = HealthLogMerge.entries(
            log: [:],
            health: [HealthDayReading(day: day)]
        )
        XCTAssertTrue(merged.isEmpty)
    }
}

@MainActor
final class HealthApplyTests: XCTestCase {
    func testHealthReadingsFeedTheTrendAndAreNotStored() {
        let session = EatWatchSession.open(inMemory: true, defaults: freshDefaults(), enableCloud: false)
        let logged = Day(year: 2024, month: 7, day: 1)
        let fromHealth = Day(year: 2024, month: 7, day: 2)
        session.store.save(WeighIn(day: logged, weightPounds: 180, note: "kept"))
        session.store.applyHealth([
            HealthDayReading(day: fromHealth, weightPounds: 179)
        ])

        XCTAssertEqual(session.store.count, 1)
        XCTAssertNil(session.store.weighIn(on: fromHealth))
        XCTAssertEqual(session.store.analysis.weighed.count, 2)
        XCTAssertEqual(session.store.analysis.point(on: fromHealth)?.weightPounds, 179)
        XCTAssertEqual(session.store.analysis.point(on: logged)?.note, "kept")

        let exported = CSVLog.export(session.store.analysis.weighed, unit: .pounds)
        XCTAssertTrue(exported.contains("2024-07-02"))
        XCTAssertTrue(exported.contains("179"))

        session.store.reload()
        XCTAssertEqual(session.store.count, 1)
        XCTAssertEqual(session.store.analysis.weighed.count, 2)
    }
}

private func freshDefaults() -> UserDefaults {
    let name = "eatwatch.health.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}
