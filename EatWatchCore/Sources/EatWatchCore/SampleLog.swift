import Foundation

public enum SampleLog {
    public static func make(ending today: Day = .today()) -> [WeighIn] {
        let start = today.adding(days: -44)
        var items: [WeighIn] = []
        for offset in 0..<45 {
            if offset % 11 == 7 { continue }
            let day = start.adding(days: offset)
            let noise = sin(Double(offset) * 0.85) * 0.65 + cos(Double(offset) * 0.33) * 0.25
            let weight = 186.4 - Double(offset) * 0.085 + noise
            var note = ""
            if offset == 20 { note = "Travel day" }
            let rung: Int? = offset % 6 == 0 ? min(12, 3 + offset / 6) : nil
            items.append(WeighIn(day: day, weightPounds: weight, rung: rung, flagged: offset % 9 == 0, note: note))
        }
        return items
    }
}
