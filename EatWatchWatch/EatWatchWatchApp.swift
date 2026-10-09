import SwiftUI
import SwiftData
import EatWatchCore

@main
struct EatWatchWatchApp: App {
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
            WatchRootView()
                .environment(session)
                .environment(session.store)
                .environment(session.settings)
        }
        .modelContainer(session.container)
    }
}
