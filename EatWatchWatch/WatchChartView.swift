import Charts
import SwiftUI
import EatWatchCore

struct WatchChartView: View {
    @Environment(LogStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        NavigationStack {
            Group {
                if displayed.isEmpty {
                    ContentUnavailableView(
                        "No chart yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Log a few mornings and the trend shows up here.")
                    )
                } else {
                    Chart(displayed) { point in
                        LineMark(
                            x: .value("Day", point.day.date()),
                            y: .value("Trend", settings.weightUnit.fromPounds(point.trendPounds))
                        )
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Trend, \(spokenDay(point.day))")
                        .accessibilityValue(spokenWeight(point.trendPounds))
                        if let weight = point.weightPounds {
                            PointMark(
                                x: .value("Day", point.day.date()),
                                y: .value("Scale", settings.weightUnit.fromPounds(weight))
                            )
                            .accessibilityLabel("Scale, \(spokenDay(point.day))")
                            .accessibilityValue(spokenWeight(weight))
                        }
                    }
                    .chartLegend(.hidden)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.month(.abbreviated).day())
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Chart")
        }
    }

    private var displayed: [DailyPoint] {
        let start = Day.today().adding(days: -30)
        return store.analysis.daily.filter { $0.day >= start }
    }

    private func spokenDay(_ day: Day) -> String {
        day.date().formatted(.dateTime.month(.wide).day().year())
    }

    private func spokenWeight(_ pounds: Double) -> String {
        switch settings.weightUnit {
        case .pounds:
            return MeasureFormat.number(pounds, digits: 1) + " pounds"
        case .kilograms:
            return MeasureFormat.number(settings.weightUnit.fromPounds(pounds), digits: 1) + " kilograms"
        case .stones:
            let absolute = abs(pounds)
            let stones = Int(absolute / WeightUnit.poundsPerStone)
            let remainder = absolute - Double(stones) * WeightUnit.poundsPerStone
            let sign = pounds < 0 ? "minus " : ""
            return "\(sign)\(stones) stones \(MeasureFormat.number(remainder, digits: 1)) pounds"
        }
    }
}
