import SwiftUI
import EatWatchCore

struct BalanceCard: View {
    var title: String
    var poundsPerDay: Double
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let kilocalories = TrendMath.kilocalories(poundsPerDay: poundsPerDay)
        VStack(alignment: .leading, spacing: 6) {
            Text("Balance")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(sentence(kilocalories))
            Text(MeasureFormat.ratePerWeek(poundsPerDay, unit: settings.weightUnit))
                .font(.title3.bold())
                .foregroundStyle(.tint)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: .rect(cornerRadius: 16))
    }

    private func sentence(_ kilocalories: Double) -> String {
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
