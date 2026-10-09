import SwiftUI
import EatWatchCore

struct WaitingReading: View {
    var latest: TrendPoint
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing logged for this morning.")
                .font(.title2.bold())
            Text("Trend \(MeasureFormat.weight(latest.trendPounds, unit: settings.weightUnit))")
                .font(.title3)
            Text("Last weigh-in \(latest.day.formatted(date: .complete))")
                .foregroundStyle(.secondary)
        }
    }
}
