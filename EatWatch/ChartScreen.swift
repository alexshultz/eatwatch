import SwiftUI
import EatWatchCore

struct ChartScreen: View {
    @Environment(LogStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var range: ChartRange = .month

    var body: some View {
        NavigationStack {
            Group {
                if store.analysis.daily.isEmpty {
                    ContentUnavailableView(
                        "No chart yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Log a few mornings and the trend line will show up here.")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Range", selection: $range) {
                            ForEach(ChartRange.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        ChartPlot(points: displayed)
                        Text(caption)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .navigationTitle("Chart")
            .settingsButton()
        }
    }

    private var displayed: [DailyPoint] {
        guard let days = range.days else { return store.analysis.daily }
        let start = Day.today().adding(days: -(days - 1))
        return store.analysis.daily.filter { $0.day >= start }
    }

    private var caption: String {
        var text = "Dots are the scale. The line is the trend, and it stays put on days you don’t weigh in."
        if settings.goalPounds != nil {
            let bandUnit: WeightUnit = settings.weightUnit == .stones ? .pounds : settings.weightUnit
            text += " The band is within \(MeasureFormat.weight(TrendMath.goalBandPounds, unit: bandUnit)) of the goal."
        }
        return text
    }
}
