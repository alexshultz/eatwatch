import SwiftUI
import EatWatchCore

struct RootView: View {
    @Environment(EatWatchSession.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @State private var section = AppSection.today
    @State private var unlocked = false

    var body: some View {
        Group {
            if settings.locksWithBiometrics && !unlocked {
                LockScreen { unlocked = true }
            } else {
                TabView(selection: $section) {
                    Tab("Today", systemImage: "scalemass", value: AppSection.today) {
                        TodayView()
                    }
                    Tab("Log", systemImage: "list.bullet", value: AppSection.log) {
                        LogListView()
                    }
                    Tab("Chart", systemImage: "chart.xyaxis.line", value: AppSection.chart) {
                        ChartScreen()
                    }
                    Tab("Plan", systemImage: "target", value: AppSection.plan) {
                        PlanView()
                    }
                }
                .tabViewStyle(.sidebarAdaptable)
                #if os(iOS)
                .defaultTabBarPlacement(.sidebar)
                #endif
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                session.refresh()
            } else if settings.locksWithBiometrics {
                unlocked = false
            }
        }
    }
}
