import Charts
import SwiftUI
import EatWatchCore

struct ChartPlot: View {
    var points: [DailyPoint]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Chart {
            goalMarks
            ForEach(points) { point in
                LineMark(
                    x: .value("Day", point.day.date()),
                    y: .value("Trend", settings.weightUnit.fromPounds(point.trendPounds))
                )
                .foregroundStyle(.tint)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.linear)
                if let weight = point.weightPounds {
                    PointMark(
                        x: .value("Day", point.day.date()),
                        y: .value("Scale", settings.weightUnit.fromPounds(weight))
                    )
                    .foregroundStyle(.primary)
                    .symbolSize(28)
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxisLabel(settings.weightUnit.abbreviation)
        .chartLegend(.hidden)
        .frame(maxWidth: .infinity, minHeight: 280, maxHeight: .infinity)
        .accessibilityLabel("Weight chart")
        .accessibilityValue(summary)
    }

    @ChartContentBuilder
    private var goalMarks: some ChartContent {
        if let goal = settings.goalPounds, let first = points.first, let last = points.last {
            let center = settings.weightUnit.fromPounds(goal)
            let band = settings.weightUnit.fromPounds(TrendMath.goalBandPounds)
            RectangleMark(
                xStart: .value("Start", first.day.date()),
                xEnd: .value("End", last.day.date()),
                yStart: .value("Low", center - band),
                yEnd: .value("High", center + band)
            )
            .foregroundStyle(.tint.opacity(0.12))
            RuleMark(y: .value("Goal", center))
                .foregroundStyle(.tint.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
    }

    private var yDomain: ClosedRange<Double> {
        var values = points.map { settings.weightUnit.fromPounds($0.trendPounds) }
        values += points.compactMap { $0.weightPounds.map { settings.weightUnit.fromPounds($0) } }
        if let goal = settings.goalPounds {
            values.append(settings.weightUnit.fromPounds(goal))
        }
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let pad = max((high - low) * 0.12, settings.weightUnit == .stones ? 0.15 : 1)
        return (low - pad)...(high + pad)
    }

    private var summary: String {
        guard let latest = points.last else { return "Empty" }
        return "Latest trend \(MeasureFormat.weight(latest.trendPounds, unit: settings.weightUnit))"
    }
}
