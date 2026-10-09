import SwiftUI
import EatWatchCore

struct TodayView: View {
    @Environment(LogStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var editing: Day?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(Day.today().longDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    todayBody
                    if let balance = store.analysis.preferredSlope() {
                        BalanceCard(title: balance.title, poundsPerDay: balance.poundsPerDay)
                    }
                    RecentDays(points: recentPoints)
                }
                .padding()
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(AppName.display)
            .settingsButton()
            .safeAreaBar(edge: .bottom) {
                Button(logTitle, action: logToday)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: 720)
            }
            .sheet(item: $editing) { day in
                EntrySheet(originalDay: day)
                    .environment(store)
                    .environment(settings)
            }
        }
    }

    @ViewBuilder
    private var todayBody: some View {
        if let today = store.analysis.point(on: .today()) {
            TodayReading(point: today)
        } else if let latest = store.analysis.latest {
            WaitingReading(latest: latest)
        } else {
            ContentUnavailableView(
                "Log this morning’s weight",
                systemImage: "scalemass",
                description: Text("Each weigh-in moves the trend a tenth of the way from where it was toward the scale. That is enough to see past a day of water. After a few mornings, the slope of the trend becomes a calorie balance.")
            )
        }
    }

    private var recentPoints: [TrendPoint] {
        store.analysis.weighed.suffix(8).reversed().filter { $0.day != .today() }
    }

    private var logTitle: String {
        store.analysis.point(on: .today()) == nil ? "Log weight" : "Edit today"
    }

    private func logToday() {
        editing = .today()
    }
}
