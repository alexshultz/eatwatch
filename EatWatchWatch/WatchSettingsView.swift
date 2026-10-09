import SwiftUI
import EatWatchCore

struct WatchSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Picker("Weight", selection: $settings.weightUnit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.name).tag(unit)
                    }
                }
                Picker("Energy", selection: $settings.energyUnit) {
                    ForEach(EnergyUnit.allCases) { unit in
                        Text(unit.name).tag(unit)
                    }
                }
                Text(settings.syncState.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
    }
}
