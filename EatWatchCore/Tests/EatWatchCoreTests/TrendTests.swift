import XCTest
@testable import EatWatchCore

final class TrendTests: XCTestCase {
    func testFirstWeightIsTheTrend() {
        let day = Day(year: 2024, month: 1, day: 1)
        let analysis = TrendEngine.analyze([WeighIn(day: day, weightPounds: 180)])
        XCTAssertEqual(analysis.weighed.count, 1)
        XCTAssertEqual(analysis.weighed[0].trendPounds, 180)
        XCTAssertEqual(analysis.weighed[0].variancePounds, 0)
    }

    func testTenPercentUpdateAndAGap() {
        let entries = [
            WeighIn(day: Day(year: 2005, month: 1, day: 1), weightPounds: 180),
            WeighIn(day: Day(year: 2005, month: 1, day: 2), weightPounds: 181),
            WeighIn(day: Day(year: 2005, month: 1, day: 3), weightPounds: 179.5),
            WeighIn(day: Day(year: 2005, month: 1, day: 5), weightPounds: 180)
        ]
        let analysis = TrendEngine.analyze(entries, through: Day(year: 2005, month: 1, day: 5))
        let trends = analysis.weighed.map(\.trendPounds)
        XCTAssertEqual(trends[0], 180, accuracy: 1e-9)
        XCTAssertEqual(trends[1], 180.1, accuracy: 1e-9)
        XCTAssertEqual(trends[2], 180.04, accuracy: 1e-9)
        XCTAssertEqual(trends[3], 180.036, accuracy: 1e-9)

        let january4 = analysis.daily.first { $0.day == Day(year: 2005, month: 1, day: 4) }
        XCTAssertEqual(january4?.weightPounds, nil)
        XCTAssertEqual(january4?.trendPounds ?? 0, 180.04, accuracy: 1e-9)
    }

    func testFlatTrendHasNoSlopeEnergy() {
        let start = Day(year: 2024, month: 3, day: 1)
        let entries = (0..<6).map { offset in
            WeighIn(day: start.adding(days: offset), weightPounds: 170)
        }
        let analysis = TrendEngine.analyze(entries, through: start.adding(days: 5))
        let slope = analysis.slope(from: start, through: start.adding(days: 5))
        XCTAssertEqual(slope ?? 99, 0, accuracy: 1e-9)
        XCTAssertEqual(TrendMath.kilocalories(poundsPerDay: slope ?? 99), 0, accuracy: 1e-6)
    }

    func testLinearFitAndCalorieScale() {
        let slope = LinearFit.slope(xs: [0, 1, 2, 3], ys: [10, 10.5, 11, 11.5])
        XCTAssertEqual(slope ?? 0, 0.5, accuracy: 1e-9)
        XCTAssertEqual(TrendMath.kilocalories(poundsPerDay: 0.1), 350, accuracy: 1e-9)
    }

    func testSlopeNeedsFourWeighIns() {
        let start = Day(year: 2024, month: 4, day: 1)
        let entries = (0..<3).map { WeighIn(day: start.adding(days: $0), weightPounds: 160 + Double($0)) }
        let analysis = TrendEngine.analyze(entries)
        XCTAssertNil(analysis.slope(from: start, through: start.adding(days: 2)))
    }

    func testRungAndFlagPassThroughWithoutChangingTheTrend() {
        let day1 = Day(year: 2024, month: 5, day: 1)
        let day2 = day1.adding(days: 1)
        let entries = [
            WeighIn(day: day1, weightPounds: 200, rung: 48, flagged: true),
            WeighIn(day: day2, weightPounds: 190, rung: 49, flagged: false)
        ]
        let analysis = TrendEngine.analyze(entries)
        XCTAssertEqual(analysis.weighed[0].rung, 48)
        XCTAssertTrue(analysis.weighed[0].flagged)
        XCTAssertNil(analysis.weighed[1].rung)
        XCTAssertFalse(analysis.weighed[1].flagged)
        let expected = 200 + 0.1 * (190 - 200)
        XCTAssertEqual(analysis.weighed[1].trendPounds, expected, accuracy: 1e-9)
    }
}
