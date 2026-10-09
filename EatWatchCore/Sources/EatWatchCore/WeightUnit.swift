import Foundation

public enum WeightUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case pounds
    case kilograms
    case stones

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .pounds: "Pounds"
        case .kilograms: "Kilograms"
        case .stones: "Stones"
        }
    }

    public var abbreviation: String {
        switch self {
        case .pounds: "lb"
        case .kilograms: "kg"
        case .stones: "st"
        }
    }

    /// International avoirdupois pound.
    public static let kilogramsPerPound = 0.45359237
    public static let poundsPerStone = 14.0

    public func toPounds(_ displayValue: Double) -> Double {
        switch self {
        case .pounds: displayValue
        case .kilograms: displayValue / Self.kilogramsPerPound
        case .stones: displayValue * Self.poundsPerStone
        }
    }

    public func fromPounds(_ pounds: Double) -> Double {
        switch self {
        case .pounds: pounds
        case .kilograms: pounds * Self.kilogramsPerPound
        case .stones: pounds / Self.poundsPerStone
        }
    }

    public var fractionDigits: Int {
        switch self {
        case .pounds, .stones: 1
        case .kilograms: 1
        }
    }
}

public enum EnergyUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case kilocalories
    case kilojoules

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .kilocalories: "Kilocalories"
        case .kilojoules: "Kilojoules"
        }
    }

    public var abbreviation: String {
        switch self {
        case .kilocalories: "kcal"
        case .kilojoules: "kJ"
        }
    }
}

public enum NumberInput {
    /// Accepts `180.2`, `180,2`, and `1,802.5`.
    public static func parse(_ raw: String) -> Double? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "\u{00a0}", with: "")
        text = text.replacingOccurrences(of: " ", with: "")
        guard !text.isEmpty else { return nil }

        if text.contains(","), text.contains(".") {
            if let comma = text.lastIndex(of: ","), let dot = text.lastIndex(of: "."), comma > dot {
                text = text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                text = text.replacingOccurrences(of: ",", with: "")
            }
        } else if text.contains(",") {
            let parts = text.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count == 2, (1...2).contains(parts[1].count) {
                text = text.replacingOccurrences(of: ",", with: ".")
            } else {
                text = text.replacingOccurrences(of: ",", with: "")
            }
        }

        return Double(text)
    }
}

public enum WeightInput {
    public static let maximumPounds = 1500.0

    public static func isPlausible(_ pounds: Double) -> Bool {
        pounds > 0 && pounds < maximumPounds
    }

    /// Reads a weight. A stone phrase such as `11 st 6` is always pounds.
    /// Any other number is converted from `unit`.
    public static func pounds(from raw: String, unit: WeightUnit) -> Double? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let stones = stonePounds(text) {
            return stones
        }

        var unitToUse = unit
        let lowered = text.lowercased()
        if lowered.contains("kg") {
            unitToUse = .kilograms
        } else if lowered.contains("lb") {
            unitToUse = .pounds
        }

        let numeric = lowered
            .replacingOccurrences(of: "kilograms", with: "")
            .replacingOccurrences(of: "kilogram", with: "")
            .replacingOccurrences(of: "pounds", with: "")
            .replacingOccurrences(of: "pound", with: "")
            .replacingOccurrences(of: "kg", with: "")
            .replacingOccurrences(of: "lbs", with: "")
            .replacingOccurrences(of: "lb", with: "")
        guard let value = NumberInput.parse(numeric) else { return nil }
        return unitToUse.toPounds(value)
    }

    public static func stonePounds(_ raw: String) -> Double? {
        let pattern = #"^\s*(\d+(?:[.,]\d+)?)\s*(?:stones|stone|st)\s*(\d+(?:[.,]\d+)?)?\s*(?:pounds|pound|lbs|lb)?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(raw.startIndex..., in: raw)
        guard let match = regex.firstMatch(in: raw, options: [], range: range),
              let stoneRange = Range(match.range(at: 1), in: raw),
              let stones = NumberInput.parse(String(raw[stoneRange])) else {
            return nil
        }
        var remainder = 0.0
        if match.range(at: 2).location != NSNotFound,
           let poundRange = Range(match.range(at: 2), in: raw),
           let pounds = NumberInput.parse(String(raw[poundRange])) {
            remainder = pounds
        }
        return stones * WeightUnit.poundsPerStone + remainder
    }
}
