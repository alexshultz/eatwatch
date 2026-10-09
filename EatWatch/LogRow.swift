import SwiftUI
import EatWatchCore

struct LogRow: View {
    var point: TrendPoint
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(point.day.formatted())
                Spacer(minLength: 8)
                Text(MeasureFormat.weight(point.weightPounds, unit: settings.weightUnit))
                    .monospacedDigit()
            }
            HStack {
                Text("Trend \(MeasureFormat.weight(point.trendPounds, unit: settings.weightUnit))")
                Spacer(minLength: 8)
                Text(MeasureFormat.delta(point.variancePounds, unit: settings.weightUnit))
                    .monospacedDigit()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            if point.flagged || point.rung != nil || !point.note.isEmpty {
                detail
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var detail: some View {
        HStack(spacing: 10) {
            if point.flagged {
                Text("Flagged")
            }
            if let rung = point.rung {
                Text("Rung \(rung)")
            }
            if !point.note.isEmpty {
                Text(point.note)
                    .lineLimit(1)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
