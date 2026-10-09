import SwiftUI
import EatWatchCore

struct WatchLogView: View {
    @Environment(LogStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var editing: Day?

    var body: some View {
        NavigationStack {
            Group {
                if store.analysis.weighed.isEmpty {
                    ContentUnavailableView(
                        "No weigh-ins",
                        systemImage: "list.bullet",
                        description: Text("Weights you log, and weights from Health, show up here.")
                    )
                } else {
                    List(store.analysis.weighed.reversed()) { point in
                        Button {
                            editing = point.day
                        } label: {
                            VStack(alignment: .leading) {
                                Text(point.day.formatted())
                                Text(MeasureFormat.weight(point.weightPounds, unit: settings.weightUnit))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log")
            .sheet(item: $editing) { day in
                WatchEntryView(originalDay: day)
                    .environment(store)
                    .environment(settings)
            }
        }
    }
}
