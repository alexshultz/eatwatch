import LocalAuthentication
import SwiftUI
import UniformTypeIdentifiers
import EatWatchCore

struct SettingsView: View {
    @Environment(EatWatchSession.self) private var session
    @Environment(LogStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var centimetersText = ""
    @State private var feetText = ""
    @State private var inchesText = ""
    @State private var importing = false
    @State private var confirmImport = false
    @State private var importAgreed = false
    @State private var exporting = false
    @State private var exportDocument = CSVFile(text: "")
    @State private var exportFilename = "\(AppName.display).csv"
    @State private var confirmDelete = false
    @State private var notice: String?
    @State private var lockError: String?

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Weight", selection: $settings.weightUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.name).tag(unit)
                        }
                    }
                    .onChange(of: settings.weightUnit) { previous, _ in
                        commitHeight(as: previous)
                        syncHeight()
                    }
                    Picker("Energy", selection: $settings.energyUnit) {
                        ForEach(EnergyUnit.allCases) { unit in
                            Text(unit.name).tag(unit)
                        }
                    }
                }

                Section("Height") {
                    if settings.weightUnit == .kilograms {
                        TextField("Centimeters", text: $centimetersText)
                            .decimalField()
                    } else {
                        TextField("Feet", text: $feetText)
                            .numberField()
                        TextField("Inches", text: $inchesText)
                            .decimalField()
                    }
                    Text("Height is only used for BMI. Leave it blank to hide BMI.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    Toggle(lockTitle, isOn: lockBinding)
                    if let lockError {
                        Text(lockError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Text("The lock stays on this device. Weigh-ins and the plan sync with the other devices on this iCloud account.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Health") {
                    Text(session.healthDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Allow Health access") {
                        Task { await session.refreshHealth() }
                    }
                }

                Section("Log file") {
                    Button("Import CSV") {
                        confirmImport = true
                    }
                    Text("\(AppName.importSavedLine) Do not include data that originated in Apple Health.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("CSV template", action: startTemplate)
                    Text("The template contains the headings Date, Weight, Rung, Flag, and Comment.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Export CSV", action: startExport)
                        .disabled(store.analysis.weighed.isEmpty)
                    Text("Export writes the CSV only after you choose where to save it. The columns are Date, Weight, Rung, Flag, and Comment, the same layout as The Hacker’s Diet Online export. The file includes every weight the trend uses, including readings from Health.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Delete all weights", role: .destructive) {
                        confirmDelete = true
                    }
                    .disabled(store.count == 0)
                    .confirmationDialog("Delete every weigh-in?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Delete all weights", role: .destructive, action: deleteAll)
                    } message: {
                        Text("Export a CSV first if you want a copy. This removes the weigh-ins stored by \(AppName.display) from this iCloud account, including the other devices signed in to it. Readings that came from Health stay in Health.")
                    }
                    if let notice {
                        Text(notice)
                            .font(.footnote)
                    }
                    if let error = store.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("iCloud") {
                    Text(settings.syncState.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let error = settings.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: version)
                    Text("\(AppName.display) is a private log for the trend method in John Walker’s The Hacker’s Diet. Each weigh-in moves the trend by a tenth of the gap between the scale and the previous trend. One pound of that trend is 3,500 kilocalories.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let dietURL {
                        Link("Read The Hacker’s Diet", destination: dietURL)
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if !os(macOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: close)
                }
                #endif
            }
            .onAppear(perform: syncHeight)
            .onDisappear(perform: commitHeight)
            .sheet(isPresented: $confirmImport, onDismiss: openImporterIfAgreed) {
                ImportAgreement {
                    importAgreed = true
                    confirmImport = false
                } onCancel: {
                    importAgreed = false
                    confirmImport = false
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
                importFile(result)
            }
            .fileExporter(
                isPresented: $exporting,
                document: exportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: exportFilename
            ) { result in
                if case .failure(let error) = result {
                    notice = error.localizedDescription
                }
            }
        }
    }

    private var lockTitle: String {
        #if os(iOS)
        "Require Face ID or a passcode"
        #else
        "Require Touch ID or a password"
        #endif
    }

    private var dietURL: URL? {
        URL(string: "https://www.fourmilab.ch/hackdiet/")
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return short ?? "1.0"
    }

    private var lockBinding: Binding<Bool> {
        Binding(
            get: { settings.locksWithBiometrics },
            set: { enabled in
                lockError = nil
                if !enabled {
                    settings.locksWithBiometrics = false
                    return
                }
                Task { await enableLock() }
            }
        )
    }

    private func close() {
        commitHeight()
        dismiss()
    }

    private func openImporterIfAgreed() {
        guard importAgreed else { return }
        importAgreed = false
        importing = true
    }

    private func startTemplate() {
        exportDocument = CSVFile(text: CSVLog.template())
        exportFilename = "\(AppName.display)-template.csv"
        exporting = true
    }

    private func startExport() {
        exportDocument = CSVFile(text: CSVLog.export(store.analysis.weighed, unit: settings.weightUnit))
        exportFilename = "\(AppName.display).csv"
        exporting = true
    }

    private func deleteAll() {
        store.deleteAll()
        notice = "The log is empty."
    }

    private func enableLock() async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lockError = error?.localizedDescription ?? "This device has no passcode set."
            return
        }
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Lock \(AppName.display) with this device’s unlock"
            )
            if ok {
                settings.locksWithBiometrics = true
            }
        } catch {
            lockError = error.localizedDescription
        }
    }

    private func syncHeight() {
        guard let centimeters = settings.heightCentimeters else {
            centimetersText = ""
            feetText = ""
            inchesText = ""
            return
        }
        centimetersText = MeasureFormat.editNumber(centimeters)
        let totalInches = centimeters / 2.54
        let feet = Int(totalInches / 12)
        let inches = totalInches - Double(feet) * 12
        feetText = String(feet)
        inchesText = MeasureFormat.editNumber(inches)
    }

    private func commitHeight() {
        commitHeight(as: settings.weightUnit)
    }

    private func commitHeight(as unit: WeightUnit) {
        if unit == .kilograms {
            let trimmed = centimetersText.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                settings.heightCentimeters = nil
            } else if let centimeters = NumberInput.parse(trimmed), (80...250).contains(centimeters) {
                settings.heightCentimeters = centimeters
            }
        } else {
            let feetBlank = feetText.trimmingCharacters(in: .whitespaces).isEmpty
            let inchesBlank = inchesText.trimmingCharacters(in: .whitespaces).isEmpty
            if feetBlank && inchesBlank {
                settings.heightCentimeters = nil
                return
            }
            let feet = NumberInput.parse(feetText) ?? 0
            let inches = NumberInput.parse(inchesText) ?? 0
            let centimeters = (feet * 12 + inches) * 2.54
            if (80...250).contains(centimeters) {
                settings.heightCentimeters = centimeters
            }
        }
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                notice = "That file is not text."
                return
            }
            let parsed = try CSVLog.parse(text, fallbackUnit: settings.weightUnit)
            let replaced = store.importEntries(parsed.entries)
            notice = "Imported \(parsed.entries.count) days. \(replaced) replaced a day already in the log. \(parsed.skipped) rows were skipped."
        } catch {
            notice = error.localizedDescription
        }
    }
}

private struct ImportAgreement: View {
    var onAgree: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(AppName.importSavedLine)
                Text(AppName.importGuidelineLine)
                Text(AppName.importDoNotIncludeLine)
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("Import only your own log")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import", action: onAgree)
                }
            }
        }
        #if os(macOS)
        .frame(width: 480, height: 280)
        #endif
    }
}
