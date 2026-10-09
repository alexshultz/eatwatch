import SwiftUI
import EatWatchCore

struct RecentDays: View {
    var points: [TrendPoint]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        if !points.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent")
                    .font(.headline)
                ForEach(points) { point in
                    HStack {
                        Text(point.day.formatted())
                        Spacer(minLength: 8)
                        Text(MeasureFormat.weight(point.weightPounds, unit: settings.weightUnit))
                            .monospacedDigit()
                        Text(MeasureFormat.delta(point.variancePounds, unit: settings.weightUnit))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}
