import SwiftUI
import EatWatchCore

struct LogListView: View {
    @Environment(EatWatchSession.self) private var session
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
                        description: Text("Weights you log, and weights from Health, show up here, newest first.")
                    )
                } else {
                    List {
                        ForEach(sections) { section in
                            Section(section.title) {
                                ForEach(section.points) { point in
                                    Button {
                                        editing = point.day
                                    } label: {
                                        LogRow(point: point)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions {
                                        if store.weighIn(on: point.day) != nil {
                                            Button("Delete", role: .destructive) {
                                                session.deleteEntry(on: point.day)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log")
            .settingsButton()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Log a weight", systemImage: "plus", action: logToday)
                }
            }
            .sheet(item: $editing) { day in
                EntrySheet(originalDay: day)
                    .environment(store)
                    .environment(settings)
            }
        }
    }

    private var sections: [LogSection] {
        var result: [LogSection] = []
        for point in store.analysis.weighed.reversed() {
            let key = "\(point.day.year)-\(point.day.month)"
            if let last = result.indices.last, result[last].id == key {
                result[last].points.append(point)
            } else {
                result.append(LogSection(id: key, title: point.day.monthTitle, points: [point]))
            }
        }
        return result
    }

    private func logToday() {
        editing = .today()
    }
}
