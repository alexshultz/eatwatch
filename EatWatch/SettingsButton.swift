import SwiftUI
import EatWatchCore

struct SettingsButton: ViewModifier {
    @Environment(LogStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var presented = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: settingsPlacement) {
                    Button("Settings", systemImage: "gearshape", action: showSettings)
                }
            }
            .sheet(isPresented: $presented) {
                SettingsView()
                    .environment(store)
                    .environment(settings)
            }
    }

    private var settingsPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #else
        .primaryAction
        #endif
    }

    private func showSettings() {
        presented = true
    }
}

extension View {
    func settingsButton() -> some View {
        modifier(SettingsButton())
    }
}
