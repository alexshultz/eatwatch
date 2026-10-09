import SwiftUI
import SwiftData
import EatWatchCore

@main
struct EatWatchApp: App {
    @State private var session: EatWatchSession

    init() {
        let sample = ProcessInfo.processInfo.arguments.contains("-sampleData")
        _session = State(initialValue: EatWatchSession.open(
            inMemory: sample,
            seed: sample ? SampleLog.make() : nil
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(session.store)
                .environment(session.settings)
        }
        .modelContainer(session.container)
        .defaultSize(width: 980, height: 740)

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(session)
                .environment(session.store)
                .environment(session.settings)
                .frame(minWidth: 460, minHeight: 520)
        }
        #endif
    }
}
