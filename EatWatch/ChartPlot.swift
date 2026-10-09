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
                .accessibilityLabel("Trend, \(spokenDay(point.day))")
                .accessibilityValue(spokenWeight(point.trendPounds, unit: settings.weightUnit))
                if let weight = point.weightPounds {
                    PointMark(
                        x: .value("Day", point.day.date()),
                        y: .value("Scale", settings.weightUnit.fromPounds(weight))
                    )
                    .foregroundStyle(.primary)
                    .symbolSize(28)
                    .accessibilityLabel("Scale, \(spokenDay(point.day))")
                    .accessibilityValue(spokenWeight(weight, unit: settings.weightUnit))
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxisLabel(settings.weightUnit.abbreviation)
        .chartLegend(.hidden)
        .frame(maxWidth: .infinity, minHeight: 280, maxHeight: .infinity)
    }

    @ChartContentBuilder
    private var goalMarks: some ChartContent {
        if let goal = settings.goalPounds, let first = points.first, let last = points.last {
            let center = settings.weightUnit.fromPounds(goal)
            let band = settings.weightUnit.fromPounds(TrendMath.goalBandPounds)
            let bandUnit: WeightUnit = settings.weightUnit == .stones ? .pounds : settings.weightUnit
            RectangleMark(
                xStart: .value("Start", first.day.date()),
                xEnd: .value("End", last.day.date()),
                yStart: .value("Low", center - band),
                yEnd: .value("High", center + band)
            )
            .foregroundStyle(.tint.opacity(0.12))
            .accessibilityLabel("Goal band")
            .accessibilityValue("Within \(spokenWeight(TrendMath.goalBandPounds, unit: bandUnit)) of \(spokenWeight(goal, unit: settings.weightUnit))")
            RuleMark(y: .value("Goal", center))
                .foregroundStyle(.tint.opacity(0.8))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .accessibilityLabel("Goal")
                .accessibilityValue(spokenWeight(goal, unit: settings.weightUnit))
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

    private func spokenDay(_ day: Day) -> String {
        day.date().formatted(.dateTime.month(.wide).day().year())
    }

    private func spokenWeight(_ pounds: Double, unit: WeightUnit) -> String {
        switch unit {
        case .pounds:
            return MeasureFormat.number(pounds, digits: 1) + " pounds"
        case .kilograms:
            return MeasureFormat.number(unit.fromPounds(pounds), digits: 1) + " kilograms"
        case .stones:
            let absolute = abs(pounds)
            let stones = Int(absolute / WeightUnit.poundsPerStone)
            let remainder = absolute - Double(stones) * WeightUnit.poundsPerStone
            let sign = pounds < 0 ? "minus " : ""
            return "\(sign)\(stones) stones \(MeasureFormat.number(remainder, digits: 1)) pounds"
        }
    }
}
