import SwiftUI
import EatWatchCore

struct WatchEntryView: View {
    var originalDay: Day

    @Environment(EatWatchSession.self) private var session
    @Environment(LogStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date
    @State private var weightText = ""
    @State private var stoneText = ""
    @State private var stonePoundText = ""
    @State private var tracksRung = false
    @State private var rung = 1
    @State private var flagged = false
    @State private var message: String?
    @State private var didLoad = false

    init(originalDay: Day) {
        self.originalDay = originalDay
        _selectedDate = State(initialValue: originalDay.date())
    }

    private var day: Day { Day(date: selectedDate) }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $selectedDate, in: ...latestSelectable, displayedComponents: .date)
                weightFields
                Toggle("Flag this day", isOn: $flagged)
                Toggle("Record a rung", isOn: $tracksRung)
                if tracksRung {
                    Stepper("Rung \(rung)", value: $rung, in: ExerciseRung.range)
                }
                if let message {
                    Text(message)
                        .foregroundStyle(.red)
                }
                if store.weighIn(on: originalDay) != nil {
                    Button("Delete this day", role: .destructive, action: deleteDay)
                }
            }
            .navigationTitle(store.weighIn(on: originalDay) == nil ? "Log" : "Edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .onAppear(perform: load)
        }
    }

    @ViewBuilder
    private var weightFields: some View {
        switch settings.weightUnit {
        case .stones:
            TextField("Stones", text: $stoneText)
            TextField("Pounds", text: $stonePoundText)
        case .pounds, .kilograms:
            TextField("Weight", text: $weightText)
        }
    }

    private var latestSelectable: Date {
        Day.today().adding(days: 1).date()
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let existing = store.weighIn(on: originalDay) else { return }
        flagged = existing.flagged
        if let existingRung = existing.rung {
            tracksRung = true
            rung = existingRung
        }
        switch settings.weightUnit {
        case .stones:
            let stones = Int(existing.weightPounds / WeightUnit.poundsPerStone)
            let remainder = existing.weightPounds - Double(stones) * WeightUnit.poundsPerStone
            stoneText = String(stones)
            stonePoundText = MeasureFormat.editNumber(remainder)
        case .pounds, .kilograms:
            weightText = MeasureFormat.editNumber(settings.weightUnit.fromPounds(existing.weightPounds))
        }
    }

    private func save() {
        guard day <= .today() else {
            message = "Pick a day that has already happened."
            return
        }
        guard let pounds = parsedPounds(), WeightInput.isPlausible(pounds) else {
            message = "Enter a weight above zero."
            return
        }
        let existing = store.weighIn(on: originalDay)
        session.saveEntry(
            WeighIn(
                day: day,
                weightPounds: pounds,
                rung: tracksRung ? rung : nil,
                flagged: flagged,
                note: existing?.note ?? ""
            ),
            replacing: originalDay
        )
        dismiss()
    }

    private func deleteDay() {
        session.deleteEntry(on: originalDay)
        dismiss()
    }

    private func parsedPounds() -> Double? {
        switch settings.weightUnit {
        case .stones:
            let stonesBlank = stoneText.trimmingCharacters(in: .whitespaces).isEmpty
            let poundsBlank = stonePoundText.trimmingCharacters(in: .whitespaces).isEmpty
            if stonesBlank && poundsBlank { return nil }
            let stones = NumberInput.parse(stoneText) ?? 0
            let pounds = NumberInput.parse(stonePoundText) ?? 0
            return stones * WeightUnit.poundsPerStone + pounds
        case .pounds, .kilograms:
            return WeightInput.pounds(from: weightText, unit: settings.weightUnit)
        }
    }
}
