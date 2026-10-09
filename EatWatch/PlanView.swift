import SwiftUI
import EatWatchCore

struct PlanView: View {
    @Environment(LogStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var span: Span = .month
    @State private var goalText = ""
    @State private var goalMessage: String?

    private enum Span: String, CaseIterable, Identifiable {
        case twoWeeks = "14 days"
        case month = "30 days"
        case quarter = "90 days"
        case all = "All"

        var id: String { rawValue }

        var days: Int? {
            switch self {
            case .twoWeeks: 14
            case .month: 30
            case .quarter: 90
            case .all: nil
            }
        }
    }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                if let trend = store.analysis.latest?.trendPounds {
                    Section("Where the trend is") {
                        LabeledContent("Trend") {
                            Text(MeasureFormat.weight(trend, unit: settings.weightUnit))
                        }
                        if let slope = currentSlope {
                            LabeledContent(span.rawValue) {
                                Text(MeasureFormat.ratePerWeek(slope, unit: settings.weightUnit))
                            }
                            Text(balanceSentence(TrendMath.kilocalories(poundsPerDay: slope)))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Log at least four weights in this window to estimate a calorie balance.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Picker("Window", selection: $span) {
                            ForEach(Span.allCases) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        if let centimeters = settings.heightCentimeters,
                           let bmi = BodyMass.index(pounds: trend, heightCentimeters: centimeters) {
                            LabeledContent("BMI from the trend") {
                                Text("\(MeasureFormat.bmi(bmi)) · \(BMIBand.classify(bmi).rawValue)")
                            }
                        }
                    }
                } else {
                    Section {
                        Text("Log a weight before setting a plan. The plan is a rate of change for the trend, not a guess from one morning on the scale.")
                    }
                }

                Section("Goal") {
                    TextField(goalPrompt, text: $goalText)
                        .decimalField()
                        .onSubmit(commitGoal)
                    if let goalMessage {
                        Text(goalMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Button("Save goal") { commitGoal() }
                    if settings.goalPounds != nil {
                        Button("Clear goal", role: .destructive) {
                            settings.goalPounds = nil
                            goalText = ""
                        }
                    }
                }

                if settings.goalPounds != nil, store.analysis.latest != nil {
                    Section("Pace") {
                        Picker("Schedule", selection: $settings.goalSchedule) {
                            ForEach(GoalSchedule.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        if settings.goalSchedule == .rate {
                            Stepper(value: $settings.displayedWeeklyRate, in: -5...5, step: 0.1) {
                                Text(MeasureFormat.weeklyRate(settings.goalPoundsPerWeek, unit: settings.weightUnit))
                            }
                        } else {
                            DatePicker("Arrive", selection: $settings.goalDate, displayedComponents: .date)
                        }
                        if let plan = energyPlan {
                            Text(planSentence(plan))
                                .font(.callout)
                        }
                    }
                }

                Section {
                    Text("The calorie figure is the slope of the trend times 3,500 kcal per pound. It is the balance of what you eat against what you burn. It is not a food diary.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Plan")
            .settingsButton()
            .onAppear(perform: syncGoalText)
            .onChange(of: settings.weightUnit) { _, _ in
                goalText = goalEditString()
            }
        }
    }

    private var goalPrompt: String {
        switch settings.weightUnit {
        case .pounds: "Goal weight in pounds"
        case .kilograms: "Goal weight in kilograms"
        case .stones: "Goal, such as 11 st 6"
        }
    }

    private var currentSlope: Double? {
        guard let first = store.analysis.weighed.first?.day else { return nil }
        let today = Day.today()
        let start = span.days.map { today.adding(days: -($0 - 1)) } ?? first
        return store.analysis.slope(from: max(start, first), through: today)
    }

    private var energyPlan: EnergyPlan? {
        guard let goal = settings.goalPounds, let trend = store.analysis.latest?.trendPounds else { return nil }
        return PlanMath.make(
            currentTrendPounds: trend,
            goalPounds: goal,
            actualPoundsPerDay: currentSlope,
            schedule: settings.goalSchedule,
            poundsPerWeek: settings.goalPoundsPerWeek,
            goalDay: settings.goalDay,
            today: .today()
        )
    }

    private func syncGoalText() {
        guard goalText.isEmpty else { return }
        goalText = goalEditString()
    }

    private func goalEditString() -> String {
        guard let goal = settings.goalPounds else { return "" }
        switch settings.weightUnit {
        case .stones:
            let stones = Int(goal / WeightUnit.poundsPerStone)
            let remainder = goal - Double(stones) * WeightUnit.poundsPerStone
            return "\(stones) st \(MeasureFormat.editNumber(remainder))"
        default:
            return MeasureFormat.editNumber(settings.weightUnit.fromPounds(goal))
        }
    }

    private func commitGoal() {
        let trimmed = goalText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            settings.goalPounds = nil
            goalMessage = nil
            return
        }
        guard let pounds = WeightInput.pounds(from: trimmed, unit: settings.weightUnit),
              WeightInput.isPlausible(pounds) else {
            goalMessage = "Enter a goal weight in \(settings.weightUnit.name.lowercased())."
            return
        }
        let wasEmpty = settings.goalPounds == nil
        settings.goalPounds = pounds
        if wasEmpty, let trend = store.analysis.latest?.trendPounds {
            settings.goalPoundsPerWeek = pounds < trend ? -1 : 0.5
        }
        goalMessage = nil
    }

    private func balanceSentence(_ kilocalories: Double) -> String {
        let amount = MeasureFormat.energy(abs(kilocalories), unit: settings.energyUnit, signed: false)
        if kilocalories > 25 {
            return "The trend is rising, about \(amount)/day above balance."
        }
        if kilocalories < -25 {
            return "The trend is falling, about \(amount)/day below balance."
        }
        return "The trend is flat."
    }

    private func planSentence(_ plan: EnergyPlan) -> String {
        let bandUnit: WeightUnit = settings.weightUnit == .stones ? .pounds : settings.weightUnit
        var lines: [String] = []
        if plan.isInsideGoalBand {
            lines.append("The trend is within \(MeasureFormat.weight(TrendMath.goalBandPounds, unit: bandUnit)) of the goal.")
        }
        if settings.goalSchedule == .date, (plan.daysToGoal ?? 1) <= 0 {
            lines.append("That date has passed. Pick a later day, or switch to a weekly rate.")
            return lines.joined(separator: " ")
        }
        if let days = plan.daysToGoal, settings.goalSchedule == .rate {
            if days < -0.5 {
                lines.append("This rate moves the trend away from the goal.")
            } else if days > 3650 {
                lines.append("At this rate the goal is more than ten years away.")
            } else if days > 0.5 {
                let arrival = Day.today().adding(days: Int(days.rounded()))
                lines.append("At this rate the trend reaches the goal around \(arrival.formatted(date: .abbreviated)).")
            }
        }
        if let adjust = plan.adjustmentKilocaloriesPerDay {
            let amount = MeasureFormat.energy(abs(adjust), unit: settings.energyUnit, signed: false)
            if adjust < -25 {
                lines.append("To follow the plan, eat about \(amount)/day less than the trend says you are eating now.")
            } else if adjust > 25 {
                lines.append("To follow the plan, eat about \(amount)/day more than the trend says you are eating now.")
            } else {
                lines.append("The current trend already matches this plan.")
            }
        } else if currentSlope == nil {
            lines.append("Log at least four weights in this window before \(AppName.display) can say what to change.")
        }
        return lines.joined(separator: " ")
    }
}
