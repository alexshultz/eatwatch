import SwiftUI
import EatWatchCore

struct EntrySheet: View {
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
    @State private var note = ""
    @State private var message: String?
    @State private var confirmDelete = false
    @State private var didLoad = false
    @State private var saved = false
    @FocusState private var weightFocused: Bool

    init(originalDay: Day) {
        self.originalDay = originalDay
        _selectedDate = State(initialValue: originalDay.date())
    }

    private var day: Day { Day(date: selectedDate) }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    in: ...latestSelectable,
                    displayedComponents: .date
                )
                weightFields
                Section("Exercise ladder") {
                    Toggle("Record a rung", isOn: $tracksRung)
                    if tracksRung {
                        Stepper("Rung \(rung)", value: $rung, in: ExerciseRung.range)
                    }
                }
                Section("Flag") {
                    Toggle("Flag this day", isOn: $flagged)
                }
                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
                if store.weighIn(on: day) == nil, let point = store.analysis.point(on: day) {
                    Section {
                        Text("Health has \(MeasureFormat.weight(point.weightPounds, unit: settings.weightUnit)) for this day. It is already in the trend and is not saved in the \(AppName.display) log. A weight you enter here is your own entry.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if day != originalDay, store.weighIn(on: day) != nil {
                    Section {
                        Text("Saving replaces the weight already logged on this day.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let message {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
                if store.weighIn(on: originalDay) != nil {
                    Section {
                        Button("Delete this day", role: .destructive) {
                            confirmDelete = true
                        }
                        .confirmationDialog("Delete this weigh-in?", isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button("Delete", role: .destructive, action: deleteDay)
                        } message: {
                            Text("This removes the day from the other devices on this iCloud account. If \(AppName.display) saved this weight to Health, that Health entry is removed too.")
                        }
                    }
                }
            }
            .navigationTitle(store.weighIn(on: originalDay) == nil ? "Log weight" : "Edit weight")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { weightFocused = false }
                }
            }
            .onAppear(perform: load)
            .sensoryFeedback(.success, trigger: saved)
        }
    }

    @ViewBuilder
    private var weightFields: some View {
        switch settings.weightUnit {
        case .stones:
            Section("Weight") {
                TextField("Stones", text: $stoneText)
                    .numberField()
                    .focused($weightFocused)
                TextField("Pounds", text: $stonePoundText)
                    .decimalField()
            }
        case .pounds, .kilograms:
            Section("Weight") {
                TextField("Weight", text: $weightText, prompt: Text(weightPrompt))
                    .decimalField()
                    .focused($weightFocused)
            }
        }
    }

    private var weightPrompt: String {
        guard let last = store.analysis.latest else { return settings.weightUnit.abbreviation }
        return "Last \(MeasureFormat.weight(last.weightPounds, unit: settings.weightUnit))"
    }

    private var latestSelectable: Date {
        Day.today().adding(days: 1).date()
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let existing = store.weighIn(on: originalDay) else { return }
        note = existing.note
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
            message = "A weight has to be a day that has already happened."
            return
        }
        guard let pounds = parsedPounds(), WeightInput.isPlausible(pounds) else {
            message = "Enter a weight above zero."
            return
        }
        session.saveEntry(
            WeighIn(
                day: day,
                weightPounds: pounds,
                rung: tracksRung ? rung : nil,
                flagged: flagged,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            ),
            replacing: originalDay
        )
        saved.toggle()
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
