import SwiftUI
import EatWatchCore

struct WatchTodayView: View {
    @Environment(LogStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var editing: Day?
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Day.today().formatted())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    reading
                    if let balance = store.analysis.preferredSlope() {
                        Text(MeasureFormat.ratePerWeek(balance.poundsPerDay, unit: settings.weightUnit))
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape", action: showSettings)
                }
            }
            .safeAreaBar(edge: .bottom) {
                Button(logTitle, action: logToday)
                    .buttonStyle(.borderedProminent)
            }
            .sheet(item: $editing) { day in
                WatchEntryView(originalDay: day)
                    .environment(store)
                    .environment(settings)
            }
            .sheet(isPresented: $showingSettings) {
                WatchSettingsView()
                    .environment(settings)
            }
        }
    }

    @ViewBuilder
    private var reading: some View {
        if let today = store.analysis.point(on: .today()) {
            Text(MeasureFormat.weight(today.weightPounds, unit: settings.weightUnit))
                .font(.title2.bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("Trend \(MeasureFormat.weight(today.trendPounds, unit: settings.weightUnit))")
                .foregroundStyle(.secondary)
        } else if let latest = store.analysis.latest {
            Text("Nothing for this morning")
                .font(.headline)
            Text("Trend \(MeasureFormat.weight(latest.trendPounds, unit: settings.weightUnit))")
                .foregroundStyle(.secondary)
        } else {
            ContentUnavailableView(
                "Log a weight",
                systemImage: "scalemass",
                description: Text("The trend starts with the first morning on the scale.")
            )
        }
    }

    private var logTitle: String {
        store.analysis.point(on: .today()) == nil ? "Log weight" : "Edit today"
    }

    private func logToday() {
        editing = .today()
    }

    private func showSettings() {
        showingSettings = true
    }
}
