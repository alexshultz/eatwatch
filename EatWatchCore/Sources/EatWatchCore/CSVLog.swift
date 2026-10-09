import Foundation

public struct ParsedCSV: Equatable, Sendable {
    public var entries: [WeighIn]
    public var skipped: Int

    public init(entries: [WeighIn], skipped: Int) {
        self.entries = entries
        self.skipped = skipped
    }
}

public enum CSVError: LocalizedError, Equatable {
    case empty
    case noWeights

    public var errorDescription: String? {
        switch self {
        case .empty:
            "That file has no rows."
        case .noWeights:
            "None of the rows had a date and a weight."
        }
    }
}

public enum CSVLog {
    /// Column layout of The Hacker's Diet Online export.
    public static let headings = "Date,Weight,Rung,Flag,Comment"

    public static func template() -> String {
        headings + "\n"
    }

    public static func export(_ points: [TrendPoint], unit: WeightUnit) -> String {
        // A stones log in the online file stores the weight in pounds.
        let weightUnit: WeightUnit = unit == .stones ? .pounds : unit
        let preference = switch unit {
        case .pounds: "pound"
        case .kilograms: "kilogram"
        case .stones: "stone"
        }
        var lines = [
            "Preferences,1.0,\(preference),\(preference),calorie,0,.",
            headings
        ]
        for point in points {
            let fields = [
                point.day.iso,
                plain(weightUnit.fromPounds(point.weightPounds), digits: 2),
                point.rung.map(String.init) ?? "",
                point.flagged ? "1" : "0",
                point.note
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func parse(_ text: String, fallbackUnit: WeightUnit) throws -> ParsedCSV {
        var source = text
        if source.hasPrefix("\u{feff}") {
            source.removeFirst()
        }
        let rows = table(from: source)
        guard !rows.isEmpty else { throw CSVError.empty }
        let preferenceUnit = rows.compactMap(preferenceUnit(in:)).first
        let headerIndex = rows.firstIndex { !mapHeader($0).columns.isEmpty }
        let dataRows: ArraySlice<[String]>
        let columns: [Field: Int]
        let headerUnit: WeightUnit?
        if let headerIndex {
            let header = mapHeader(rows[headerIndex])
            dataRows = rows[(headerIndex + 1)...]
            columns = header.columns
            headerUnit = header.unit
        } else {
            dataRows = rows[...]
            columns = [:]
            headerUnit = nil
        }

        var byDay: [Day: WeighIn] = [:]
        var skipped = 0
        for row in dataRows {
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                continue
            }
            guard let entry = entry(
                from: row,
                columns: columns,
                headerUnit: headerUnit,
                preferenceUnit: preferenceUnit,
                fallbackUnit: fallbackUnit
            ) else {
                skipped += 1
                continue
            }
            byDay[entry.day] = entry
        }

        let entries = byDay.values.sorted { $0.day < $1.day }
        guard !entries.isEmpty else { throw CSVError.noWeights }
        return ParsedCSV(entries: entries, skipped: skipped)
    }

    private enum Field: String {
        case date, weight, note, rung, flag, unit
    }

    private static func mapHeader(_ row: [String]) -> (columns: [Field: Int], unit: WeightUnit?) {
        var columns: [Field: Int] = [:]
        var unit: WeightUnit?
        for (index, cell) in row.enumerated() {
            let name = cell.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !name.isEmpty else { continue }
            if name.contains("weight") {
                columns[.weight] = index
                if name.contains("kg") { unit = .kilograms }
                if name.contains("lb") || name.contains("pound") { unit = .pounds }
                if name.contains("st") { unit = .stones }
            } else if name == "unit" || name == "units" {
                columns[.unit] = index
            } else if ["date", "day", "time"].contains(name) {
                columns[.date] = index
            } else if ["note", "notes", "comment", "comments"].contains(name) {
                columns[.note] = index
            } else if name == "rung" || name == "exercise" || name == "ladder" {
                columns[.rung] = index
            } else if name == "flag" || name == "flg" || name == "flagged" {
                columns[.flag] = index
            }
        }
        if columns[.date] == nil || columns[.weight] == nil {
            return ([:], nil)
        }
        return (columns, unit)
    }

    /// The online export names its log unit on a `Preferences` line before the column headings.
    /// A stones log stores the weight numbers in pounds.
    private static func preferenceUnit(in row: [String]) -> WeightUnit? {
        guard cell(row, 0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "preferences" else {
            return nil
        }
        let name = cell(row, 2).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch name {
        case "kg", "kgs", "kilogram", "kilograms": return .kilograms
        case "lb", "lbs", "pound", "pounds": return .pounds
        case "st", "stone", "stones": return .pounds
        default: return nil
        }
    }

    private static func entry(
        from row: [String],
        columns: [Field: Int],
        headerUnit: WeightUnit?,
        preferenceUnit: WeightUnit?,
        fallbackUnit: WeightUnit
    ) -> WeighIn? {
        if columns.isEmpty {
            return headerless(row, fallbackUnit: preferenceUnit ?? fallbackUnit)
        }
        guard let dateIndex = columns[.date], let weightIndex = columns[.weight] else { return nil }
        guard let day = parseDay(cell(row, dateIndex)) else { return nil }

        var unit = headerUnit ?? preferenceUnit ?? fallbackUnit
        if let unitIndex = columns[.unit] {
            unit = unitNamed(cell(row, unitIndex)) ?? unit
        }
        guard let pounds = WeightInput.pounds(from: cell(row, weightIndex), unit: unit),
              WeightInput.isPlausible(pounds) else {
            return nil
        }

        var rung: Int?
        if let rungIndex = columns[.rung] {
            rung = ExerciseRung.accepted(Int(cell(row, rungIndex).trimmingCharacters(in: .whitespaces)))
        }
        let flagged = columns[.flag].map { flaggedValue(cell(row, $0)) } ?? false
        let note = columns[.note].map { cell(row, $0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        return WeighIn(day: day, weightPounds: pounds, rung: rung, flagged: flagged, note: note)
    }

    private static func headerless(_ row: [String], fallbackUnit: WeightUnit) -> WeighIn? {
        guard let day = parseDay(cell(row, 0)) else { return nil }
        guard let pounds = WeightInput.pounds(from: cell(row, 1), unit: fallbackUnit),
              WeightInput.isPlausible(pounds) else {
            return nil
        }
        if let online = onlineTail(row) {
            return WeighIn(
                day: day,
                weightPounds: pounds,
                rung: online.rung,
                flagged: online.flagged,
                note: online.note
            )
        }
        let texts = row.dropFirst(2).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { cell in
            !cell.isEmpty && NumberInput.parse(cell) == nil && WeightInput.stonePounds(cell) == nil
        }
        return WeighIn(day: day, weightPounds: pounds, note: texts.joined(separator: " "))
    }

    /// A heading-free row in the online order: weight, rung, flag, comment.
    private static func onlineTail(_ row: [String]) -> (rung: Int?, flagged: Bool, note: String)? {
        let rungText = cell(row, 2).trimmingCharacters(in: .whitespacesAndNewlines)
        let flagText = cell(row, 3).trimmingCharacters(in: .whitespacesAndNewlines)
        let rungBlank = rungText.isEmpty
        let rung = Int(rungText)
        guard rungBlank || rung != nil else { return nil }
        guard flagText.isEmpty || flagText == "0" || flagText == "1" else { return nil }
        let note = row.dropFirst(4)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return (rung, flagText == "1", note)
    }

    /// The online log sets the checkbox only for `1`. A blank or `0` leaves it clear.
    private static func flaggedValue(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }

    private static func cell(_ row: [String], _ index: Int) -> String {
        guard row.indices.contains(index) else { return "" }
        return row[index]
    }

    private static func unitNamed(_ raw: String) -> WeightUnit? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch name {
        case "lb", "lbs", "pound", "pounds": return .pounds
        case "kg", "kgs", "kilogram", "kilograms": return .kilograms
        case "st", "stone", "stones": return .stones
        default: return nil
        }
    }

    static func parseDay(_ raw: String) -> Day? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let day = Day(iso: String(text.prefix(10))), text.count == 10 || text.count > 10 && (text.dropFirst(10).first == "T" || text.dropFirst(10).first == " ") {
            return day
        }
        if let day = Day(iso: text) { return day }

        let formats = [
            "yyyy/MM/dd",
            "M/d/yyyy",
            "M/d/yy",
            "d-MMM-yyyy",
            "MMM d, yyyy",
            "d MMM yyyy"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.isLenient = false
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return Day(date: date)
            }
        }
        return nil
    }

    private static func table(from raw: String) -> [[String]] {
        // Swift treats CRLF as one Character, which would hide the line break.
        let text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let separator = separator(in: text)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = text.startIndex

        func endRow() {
            row.append(field)
            field = ""
            if row.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                rows.append(row)
            }
            row = []
        }

        while index < text.endIndex {
            let character = text[index]
            if inQuotes {
                if character == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = text.index(after: next)
                        continue
                    }
                    inQuotes = false
                } else {
                    field.append(character)
                }
            } else if character == "\"" && field.isEmpty {
                inQuotes = true
            } else if character == separator {
                row.append(field)
                field = ""
            } else if character == "\n" {
                endRow()
            } else {
                field.append(character)
            }
            index = text.index(after: index)
        }
        if inQuotes || !field.isEmpty || !row.isEmpty {
            endRow()
        }
        return rows
    }

    private static func separator(in text: String) -> Character {
        var commas = 0
        var semicolons = 0
        var inQuotes = false
        for character in text {
            if character == "\"" {
                inQuotes.toggle()
            } else if !inQuotes && character == "\n" {
                break
            } else if !inQuotes && character == "," {
                commas += 1
            } else if !inQuotes && character == ";" {
                semicolons += 1
            }
        }
        return semicolons > commas ? ";" : ","
    }

    private static func plain(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}
