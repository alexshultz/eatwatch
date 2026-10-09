import SwiftUI
import EatWatchCore

struct WatchRootView: View {
    @Environment(EatWatchSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var section = WatchSection.today

    var body: some View {
        TabView(selection: $section) {
            Tab("Today", systemImage: "scalemass", value: WatchSection.today) {
                WatchTodayView()
            }
            Tab("Log", systemImage: "list.bullet", value: WatchSection.log) {
                WatchLogView()
            }
            Tab("Chart", systemImage: "chart.xyaxis.line", value: WatchSection.chart) {
                WatchChartView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                session.refresh()
            }
        }
    }
}
