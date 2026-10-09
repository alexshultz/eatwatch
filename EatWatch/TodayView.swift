import SwiftUI
import EatWatchCore

struct TodayView: View {
    @Environment(LogStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var editing: Day?

    var body: some View {
        NavigationStack {
            Group {
                if store.analysis.latest == nil {
                    ContentUnavailableView(
                        "Log this morning’s weight",
                        systemImage: "scalemass",
                        description: Text("Each weigh-in moves the trend a tenth of the way from where it was toward the scale. That is enough to see past a day of water. After a few mornings, the slope of the trend becomes a calorie balance.")
                    )
                } else {
                    todayList
                }
            }
            .navigationTitle(AppName.display)
            .settingsButton()
            .safeAreaBar(edge: .bottom) {
                Button(logTitle, action: logToday)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .sheet(item: $editing) { day in
                EntrySheet(originalDay: day)
                    .environment(store)
                    .environment(settings)
            }
        }
    }

    private var todayList: some View {
        let list = List {
            todaySection
            if let balance = store.analysis.preferredSlope() {
                Section("Balance") {
                    Text(balanceSentence(balance.poundsPerDay, title: balance.title))
                    Text(MeasureFormat.ratePerWeek(balance.poundsPerDay, unit: settings.weightUnit))
                        .font(.title3.bold())
                        .foregroundStyle(.tint)
                }
            }
            if !recentPoints.isEmpty {
                Section("Recent") {
                    ForEach(recentPoints) { point in
                        LabeledContent(point.day.formatted()) {
                            VStack(alignment: .trailing) {
                                Text(MeasureFormat.weight(point.weightPounds, unit: settings.weightUnit))
                                    .monospacedDigit()
                                Text(MeasureFormat.delta(point.variancePounds, unit: settings.weightUnit))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .selectionDisabled()
                    }
                }
            }
        }
        #if os(macOS)
        return list.listStyle(.inset)
        #else
        return list.listStyle(.insetGrouped)
        #endif
    }

    @ViewBuilder
    private var todaySection: some View {
        if let today = store.analysis.point(on: .today()) {
            Section {
                Text(today.day.longDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(MeasureFormat.weight(today.weightPounds, unit: settings.weightUnit))
                    .font(.largeTitle)
                    .accessibilityLabel("Weight \(MeasureFormat.weight(today.weightPounds, unit: settings.weightUnit))")
                LabeledContent("Trend") {
                    Text(MeasureFormat.weight(today.trendPounds, unit: settings.weightUnit))
                        .monospacedDigit()
                }
                LabeledContent("Variance") {
                    Text(MeasureFormat.delta(today.variancePounds, unit: settings.weightUnit))
                        .monospacedDigit()
                }
                if today.flagged {
                    LabeledContent("Flag", value: "Yes")
                }
                if let rung = today.rung {
                    LabeledContent("Rung", value: "\(rung)")
                }
                if !today.note.isEmpty {
                    Text(today.note)
                }
            } footer: {
                Text("Variance is the scale minus the trend. A thirsty day shows up here, and the trend leaves it behind.")
            }
        } else if let latest = store.analysis.latest {
            Section {
                WaitingReading(latest: latest)
            }
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

    private func balanceSentence(_ poundsPerDay: Double, title: String) -> String {
        let kilocalories = TrendMath.kilocalories(poundsPerDay: poundsPerDay)
        let amount = MeasureFormat.energy(abs(kilocalories), unit: settings.energyUnit, signed: false)
        if kilocalories > 25 {
            return "Over \(title), the trend is rising, about \(amount)/day above balance."
        }
        if kilocalories < -25 {
            return "Over \(title), the trend is falling, about \(amount)/day below balance."
        }
        return "Over \(title), the trend is flat."
    }
}
