import XCTest
@testable import EatWatchCore

final class PlanAndCSVTests: XCTestCase {
    func testRatePlanCountsDaysAndTheCalorieGap() {
        let today = Day(year: 2024, month: 6, day: 1)
        let plan = PlanMath.make(
            currentTrendPounds: 180,
            goalPounds: 170,
            actualPoundsPerDay: -0.1,
            schedule: .rate,
            poundsPerWeek: -1,
            goalDay: today.adding(days: 90),
            today: today
        )
        XCTAssertEqual(plan.daysToGoal ?? 0, 70, accuracy: 1e-6)
        let expectedAdjustment = ((-1.0 / 7.0) - (-0.1)) * 3500
        XCTAssertEqual(plan.adjustmentKilocaloriesPerDay ?? 0, expectedAdjustment, accuracy: 1e-6)
        XCTAssertFalse(plan.isInsideGoalBand)
    }

    func testWrongWayRateIsNegativeDays() {
        let today = Day(year: 2024, month: 6, day: 1)
        let plan = PlanMath.make(
            currentTrendPounds: 180,
            goalPounds: 170,
            actualPoundsPerDay: 0,
            schedule: .rate,
            poundsPerWeek: 1,
            goalDay: today,
            today: today
        )
        XCTAssertLessThan(plan.daysToGoal ?? 0, 0)
    }

    func testPastGoalDateHasNoDesiredRate() {
        let today = Day(year: 2024, month: 6, day: 10)
        let plan = PlanMath.make(
            currentTrendPounds: 180,
            goalPounds: 170,
            actualPoundsPerDay: nil,
            schedule: .date,
            poundsPerWeek: -1,
            goalDay: Day(year: 2024, month: 6, day: 1),
            today: today
        )
        XCTAssertNil(plan.desiredPoundsPerDay)
        XCTAssertNil(plan.adjustmentKilocaloriesPerDay)
    }

    func testGoalBand() {
        let today = Day(year: 2024, month: 1, day: 1)
        let plan = PlanMath.make(
            currentTrendPounds: 160,
            goalPounds: 161,
            actualPoundsPerDay: 0,
            schedule: .rate,
            poundsPerWeek: -1,
            goalDay: today,
            today: today
        )
        XCTAssertTrue(plan.isInsideGoalBand)
    }

    func testBodyMass() {
        let bmi = BodyMass.index(pounds: 150, heightCentimeters: 180)
        let kilograms = 150 * 0.45359237
        XCTAssertEqual(bmi ?? 0, kilograms / (1.8 * 1.8), accuracy: 1e-9)
        XCTAssertEqual(BMIBand.classify(22), .normal)
    }

    func testCSVRoundTripAndQuotedNote() {
        let points = [
            TrendPoint(day: Day(year: 2024, month: 1, day: 1), weightPounds: 180.25, trendPounds: 180, note: "Hello, \"friend\""),
            TrendPoint(day: Day(year: 2024, month: 1, day: 2), weightPounds: 180.5, trendPounds: 180.05, rung: 4, flagged: true)
        ]
        let text = CSVLog.export(points, unit: .pounds)
        XCTAssertTrue(text.contains("Date,Weight,Rung,Flag,Comment"))
        let parsed = try? CSVLog.parse(text, fallbackUnit: .kilograms)
        XCTAssertEqual(parsed?.entries.count, 2)
        XCTAssertEqual(parsed?.entries[0].weightPounds ?? 0, 180.25, accuracy: 0.001)
        XCTAssertEqual(parsed?.entries[0].note, "Hello, \"friend\"")
        XCTAssertFalse(parsed?.entries[0].flagged ?? true)
        XCTAssertEqual(parsed?.entries[1].rung, 4)
        XCTAssertEqual(parsed?.entries[1].flagged, true)
    }

    func testDisplayNameAgreementUsesSaves() {
        XCTAssertEqual(
            AppName.importSavedLine,
            "\(AppName.display) saves imported data to the \(AppName.display) iCloud log."
        )
        XCTAssertTrue(AppName.importSavedLine.contains("saves imported"))
    }

    func testTemplateIsTheOnlineHeading() {
        XCTAssertEqual(CSVLog.template(), "Date,Weight,Rung,Flag,Comment\n")
    }

    func testOnlineExportLayout() throws {
        let online = """
        Epoch,2007-04-28T19:35:50Z
        Preferences,1.0,kilogram,kilogram,calorie,0,.
        Date,Weight,Rung,Flag,Comment
        StartTrend,75.0163,0,1177788855,1177788855,1.0
        2007-02-01,75.2,36,0,
        2007-02-03,75.9,36,1,London
        """
        let parsed = try CSVLog.parse(online, fallbackUnit: .pounds)
        XCTAssertEqual(parsed.entries.count, 2)
        XCTAssertEqual(parsed.entries[0].weightPounds, WeightUnit.kilograms.toPounds(75.2), accuracy: 0.001)
        XCTAssertEqual(parsed.entries[0].rung, 36)
        XCTAssertFalse(parsed.entries[0].flagged)
        XCTAssertEqual(parsed.entries[0].note, "")
        XCTAssertTrue(parsed.entries[1].flagged)
        XCTAssertEqual(parsed.entries[1].note, "London")
        XCTAssertEqual(parsed.skipped, 1)
    }

    func testRungStopsAtFortyEightAndABlankFlagStaysClear() throws {
        let text = """
        Date,Weight,Rung,Flag,Comment
        2024-04-01,180,48,1,top
        2024-04-02,181,49,0,too high
        2024-04-03,182,,0,
        """
        let parsed = try CSVLog.parse(text, fallbackUnit: .pounds)
        XCTAssertEqual(parsed.entries[0].rung, 48)
        XCTAssertTrue(parsed.entries[0].flagged)
        XCTAssertNil(parsed.entries[1].rung)
        XCTAssertFalse(parsed.entries[1].flagged)
        XCTAssertNil(parsed.entries[2].rung)
        XCTAssertEqual(parsed.entries.count, 3)
    }

    func testHeaderlessAndKilogramHeader() throws {
        XCTAssertEqual(CSVLog.parseDay("2024-01-01")?.iso, "2024-01-01")
        let headerless = "2024-01-01,180.5\r\n2024-01-02,181,180.1,0.9,a note\r\n"
        let parsed = try CSVLog.parse(headerless, fallbackUnit: .pounds)
        XCTAssertEqual(parsed.entries.count, 2)
        XCTAssertEqual(parsed.entries[1].note, "a note")
        XCTAssertEqual(parsed.entries[1].weightPounds, 181, accuracy: 1e-9)

        let kilograms = "Date,Weight (kg)\n2024-02-01,80\n"
        let metric = try CSVLog.parse(kilograms, fallbackUnit: .pounds)
        XCTAssertEqual(metric.entries[0].weightPounds, 80 / 0.45359237, accuracy: 0.001)
    }

    func testStonePhraseAndSemicolonFile() throws {
        let stones = "Date;Weight;Note\n2024-03-01;11 st 6 lb;morning\n"
        let parsed = try CSVLog.parse(stones, fallbackUnit: .kilograms)
        XCTAssertEqual(parsed.entries[0].weightPounds, 160, accuracy: 1e-9)
        XCTAssertEqual(parsed.entries[0].note, "morning")
    }

    func testDecimalCommaWeight() {
        XCTAssertEqual(NumberInput.parse("80,4") ?? 0, 80.4, accuracy: 1e-9)
        XCTAssertEqual(NumberInput.parse("1,802.5") ?? 0, 1802.5, accuracy: 1e-9)
    }

    func testEmptyFileFails() {
        XCTAssertThrowsError(try CSVLog.parse("   \n", fallbackUnit: .pounds))
    }

    func testUnits() {
        XCTAssertEqual(WeightUnit.kilograms.toPounds(1), 1 / 0.45359237, accuracy: 1e-9)
        XCTAssertEqual(WeightUnit.stones.toPounds(1), 14, accuracy: 1e-9)
        XCTAssertEqual(WeightInput.stonePounds("11 stone 6") ?? 0, 160, accuracy: 1e-9)
    }
}
