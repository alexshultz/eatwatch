import Foundation

public enum MeasureFormat {
    public static func weight(_ pounds: Double, unit: WeightUnit) -> String {
        switch unit {
        case .pounds:
            return number(pounds, digits: 1) + " lb"
        case .kilograms:
            return number(unit.fromPounds(pounds), digits: 1) + " kg"
        case .stones:
            return stoneText(pounds)
        }
    }

    /// A change. Stone mode uses pounds, because a tenth of a stone hides the noise.
    public static func delta(_ pounds: Double, unit: WeightUnit) -> String {
        let display: WeightUnit = unit == .stones ? .pounds : unit
        let digits = display == .kilograms ? 2 : 1
        return number(display.fromPounds(pounds), digits: digits, signed: true) + " " + display.abbreviation
    }

    public static func ratePerWeek(_ poundsPerDay: Double, unit: WeightUnit) -> String {
        let display: WeightUnit = unit == .stones ? .pounds : unit
        let perWeek = display.fromPounds(poundsPerDay * 7)
        return number(perWeek, digits: 2, signed: true) + " " + display.abbreviation + "/week"
    }

    public static func weeklyRate(_ poundsPerWeek: Double, unit: WeightUnit) -> String {
        let display: WeightUnit = unit == .stones ? .pounds : unit
        return number(display.fromPounds(poundsPerWeek), digits: 2, signed: true) + " " + display.abbreviation + "/week"
    }

    public static func energy(_ kilocalories: Double, unit: EnergyUnit, signed: Bool = true) -> String {
        let value = unit == .kilojoules ? kilocalories * TrendMath.kilojoulesPerKilocalorie : kilocalories
        let quiet = abs(value.rounded()) < 0.5
        return number(value, digits: 0, signed: signed && !quiet) + " " + unit.abbreviation
    }

    public static func energyPerDay(_ kilocalories: Double, unit: EnergyUnit) -> String {
        energy(kilocalories, unit: unit) + "/day"
    }

    public static func editNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    public static func bmi(_ value: Double) -> String {
        number(value, digits: 1)
    }

    public static func number(_ value: Double, digits: Int, signed: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        formatter.usesGroupingSeparator = true
        if signed {
            formatter.positivePrefix = formatter.plusSign
            formatter.negativePrefix = formatter.minusSign
        }
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func stoneText(_ pounds: Double) -> String {
        let sign = pounds < 0 ? "−" : ""
        let absolute = abs(pounds)
        let stones = Int(absolute / WeightUnit.poundsPerStone)
        let remainder = absolute - Double(stones) * WeightUnit.poundsPerStone
        return "\(sign)\(stones) st \(number(remainder, digits: 1)) lb"
    }
}
