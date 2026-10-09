import SwiftUI
import EatWatchCore

struct TodayReading: View {
    var point: TrendPoint
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(MeasureFormat.weight(point.weightPounds, unit: settings.weightUnit))
                .font(.largeTitle.scaled(by: 1.5))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .accessibilityLabel("Weight \(MeasureFormat.weight(point.weightPounds, unit: settings.weightUnit))")
            Text("Trend \(MeasureFormat.weight(point.trendPounds, unit: settings.weightUnit))")
                .font(.title3)
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    metrics
                }
                VStack(alignment: .leading, spacing: 12) {
                    metrics
                }
            }
            Text("Variance is the scale minus the trend. A thirsty day shows up here, and the trend leaves it behind.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if !point.note.isEmpty {
                Text(point.note)
            }
        }
    }

    @ViewBuilder
    private var metrics: some View {
        Metric(title: "Variance", value: MeasureFormat.delta(point.variancePounds, unit: settings.weightUnit))
        if point.flagged {
            Metric(title: "Flag", value: "Yes")
        }
        if let rung = point.rung {
            Metric(title: "Rung", value: "\(rung)")
        }
    }
}
