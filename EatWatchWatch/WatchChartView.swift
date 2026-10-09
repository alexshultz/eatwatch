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
                        if let weight = point.weightPounds {
                            PointMark(
                                x: .value("Day", point.day.date()),
                                y: .value("Scale", settings.weightUnit.fromPounds(weight))
                            )
                        }
                    }
                    .chartLegend(.hidden)
                    .chartXAxis(.hidden)
                    .accessibilityLabel("Weight chart")
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
}
