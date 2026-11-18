//
//  WeekPlanView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct WeekPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \WeekPlan.weekStart, order: .reverse) private var plans: [WeekPlan]
    @Query private var trades: [Trade]

    @State private var selectedWeek: Date = WeekPlanView.currentWeekStart()
    @State private var didEnsure = false

    private var calendar: Calendar { WeekPlanView.weekCalendar }
    private var currentWeek: Date { WeekPlanView.currentWeekStart() }

    private var pastPlans: [WeekPlan] {
        plans
            .filter { calendar.startOfDay(for: $0.weekStart) < currentWeek }
            .sorted { $0.weekStart > $1.weekStart }
    }

    private var selectedPlan: WeekPlan? {
        plans.first { calendar.isDate($0.weekStart, equalTo: selectedWeek, toGranularity: .day) }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                    header

                    if let plan = selectedPlan {
                        WeekPlanEditor(
                            plan: plan,
                            weekR: weekR(for: plan.weekStart),
                            isCurrent: calendar.isDate(plan.weekStart, equalTo: currentWeek, toGranularity: .day),
                            canRepeatPrevious: canRepeatPrevious(for: plan),
                            onRepeatPrevious: { repeatPreviousWeek(into: plan) },
                            onSelectCurrent: {
                                selectedWeek = currentWeek
                                Haptics.select()
                            }
                        )
                    }

                    if !pastPlans.isEmpty {
                        SectionLabel(text: "Прошлые недели")
                            .padding(.top, 6)

                        ForEach(pastPlans) { plan in
                            pastRow(plan)
                        }
                    }

                    InfoHint(
                        text: "Планы недель хранятся в приложении и попадают в резервную копию.",
                        icon: "info.circle"
                    )
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .onAppear(perform: ensureCurrentPlan)
    }

    // MARK: - Header

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .glassCircle()
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }
            .buttonStyle(.plain)

            SectionLabel(text: "Неделя")

            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScreenTitle(text: "Недельный план")
            Text(headerSubtitle)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerSubtitle: String {
        let target = selectedPlan?.targetR ?? 6
        return "\(WeekPlanView.rangeText(for: selectedWeek)) · \(Fmt.r(weekR(for: selectedWeek))) из \(WeekPlanView.goalText(target))"
    }

    // MARK: - Past weeks

    private func pastRow(_ plan: WeekPlan) -> some View {
        Button {
            selectedWeek = calendar.startOfDay(for: plan.weekStart)
            Haptics.tap()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(WeekPlanView.rangeText(for: plan.weekStart))
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(plan.theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Без темы" : plan.theme)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(Fmt.r(weekR(for: plan.weekStart)))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(weekTint(weekR(for: plan.weekStart)))

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private func weekR(for start: Date) -> Double {
        let monday = calendar.startOfDay(for: start)
        guard let end = calendar.date(byAdding: .day, value: 7, to: monday) else { return 0 }

        return trades
            .filter { $0.result != .open }
            .filter {
                let day = calendar.startOfDay(for: $0.tradingDay)
                return day >= monday && day < end
            }
            .reduce(0) { $0 + $1.actualR }
    }

    private func weekTint(_ value: Double) -> Color {        if value > 0.05 { return Theme.green }
        if value < -0.05 { return Theme.red }
        return Theme.textSecondary
    }

    private func canRepeatPrevious(for plan: WeekPlan) -> Bool {
        guard calendar.isDate(plan.weekStart, equalTo: currentWeek, toGranularity: .day),
              isPlanEmpty(plan),
              let previous = pastPlans.first else {
            return false
        }

        let hasTheme = !previous.theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasScenarioTitles = previous.sortedScenarios.contains {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return hasTheme || hasScenarioTitles
    }

    private func isPlanEmpty(_ plan: WeekPlan) -> Bool {
        let themeEmpty = plan.theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let titlesEmpty = plan.scenarios.allSatisfy {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return themeEmpty && titlesEmpty
    }

    private func repeatPreviousWeek(into plan: WeekPlan) {
        guard isPlanEmpty(plan), let previous = pastPlans.first else { return }

        plan.theme = previous.theme
        plan.targetR = previous.targetR

        let old = plan.scenarios
        plan.scenarios.removeAll()
        for scenario in old {
            context.delete(scenario)
        }

        for (index, source) in previous.sortedScenarios.enumerated() {
            let copy = WeekScenario(title: source.title, note: source.note, position: index)
            context.insert(copy)
            plan.scenarios.append(copy)
        }

        plan.updatedAt = .now
        try? context.save()
        Haptics.success()
    }

    private func ensureCurrentPlan() {        guard !didEnsure else { return }
        didEnsure = true

        let exists = plans.contains { calendar.isDate($0.weekStart, equalTo: currentWeek, toGranularity: .day) }
        guard !exists else { return }

        let plan = WeekPlan(weekStart: currentWeek)
        context.insert(plan)

        for index in 0..<2 {
            let scenario = WeekScenario(position: index)
            context.insert(scenario)
            plan.scenarios.append(scenario)
        }

        try? context.save()
        selectedWeek = currentWeek
    }

    // MARK: - Dates

    static let weekCalendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }()

    static func currentWeekStart() -> Date {
        let calendar = weekCalendar
        let today = calendar.startOfDay(for: .now)
        return calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    }

    static func rangeText(for start: Date) -> String {
        let calendar = weekCalendar
        let monday = calendar.startOfDay(for: start)
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday

        let startMonth = calendar.component(.month, from: monday)
        let endMonth = calendar.component(.month, from: sunday)
        let startDay = calendar.component(.day, from: monday)
        let endDay = calendar.component(.day, from: sunday)

        if startMonth == endMonth {
            return "\(startDay)–\(endDay) \(monthName(monday))"
        }
        return "\(startDay) \(monthName(monday)) – \(endDay) \(monthName(sunday))"
    }

    static func goalText(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return String(format: "%.0fR", rounded)
        }
        return String(format: "%.1fR", value)
    }

    private static func monthName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL"
        return formatter.string(from: date).lowercased()
    }
}

// MARK: - Editor

private struct WeekPlanEditor: View {
    @Bindable var plan: WeekPlan
    let weekR: Double
    let isCurrent: Bool
    let canRepeatPrevious: Bool
    let onRepeatPrevious: () -> Void
    let onSelectCurrent: () -> Void

    @Environment(\.modelContext) private var context

    private var progress: Double {
        guard plan.targetR > 0 else { return 0 }
        return weekR / plan.targetR
    }

    private var percentText: String {
        "\(Int((progress * 100).rounded()))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                SectionLabel(text: "Цель недели")
                Spacer(minLength: 8)
                if !isCurrent {
                    Button {
                        onSelectCurrent()
                    } label: {
                        Text("Текущая неделя")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Fmt.r(weekR)) из \(WeekPlanView.goalText(plan.targetR))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .contentTransition(.numericText())

                Spacer(minLength: 8)

                Text(percentText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: proxy.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 6)
            .animation(.easeInOut(duration: 0.35), value: progress)

            HStack(spacing: 10) {
                Text("ТЕМА НЕДЕЛИ")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 104, alignment: .leading)

                TextField("Например: только A+ сетапы", text: $plan.theme)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
            }

            HStack(spacing: 10) {
                Text("ЦЕЛЬ ПО R")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 104, alignment: .leading)

                TextField("6R", value: $plan.targetR, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
            }

            if canRepeatPrevious {
                Button(action: onRepeatPrevious) {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Повторить прошлую неделю")
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.accent.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(0.45), lineWidth: 0.8)
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.top, 2)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
        .reveal(.zoom)

        scenariosSection
    }

    private var scenariosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(plan.sortedScenarios.enumerated()), id: \.element.persistentModelID) { index, scenario in
                ScenarioCard(
                    scenario: scenario,
                    index: index,
                    canRemove: plan.scenarios.count > 1,
                    onRemove: { remove(scenario) }
                )
                .reveal(.rise, index)
            }

            if plan.scenarios.count < 3 {
                Button(action: addScenario) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Добавить сценарий")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.accent.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(0.45), lineWidth: 0.8)
                    )
                }
                .buttonStyle(PressableButtonStyle())
            }

            PrimaryButton(title: "Сохранить неделю") {
                plan.updatedAt = .now
                try? context.save()
                WeekPlanReminder.refresh(context: context)
                Haptics.success()
            }
            .padding(.top, 4)
        }
    }

    private func addScenario() {
        guard plan.scenarios.count < 3 else { return }
        let scenario = WeekScenario(position: plan.scenarios.count)
        context.insert(scenario)
        plan.scenarios.append(scenario)
        plan.updatedAt = .now
        try? context.save()
        Haptics.tap()
    }

    private func remove(_ scenario: WeekScenario) {
        guard plan.scenarios.count > 1 else { return }
        plan.scenarios.removeAll { $0.persistentModelID == scenario.persistentModelID }
        context.delete(scenario)
        plan.updatedAt = .now
        try? context.save()
        Haptics.tap()
    }
}

// MARK: - Scenario

private struct ScenarioCard: View {
    @Bindable var scenario: WeekScenario
    let index: Int
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                SectionLabel(text: "Сценарий \(index + 1)")

                Spacer(minLength: 8)

                Button(action: onRemove) {
                    Text("Убрать")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(canRemove ? Theme.textSecondary : Theme.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .disabled(!canRemove)
            }

            TextField("Что хочу отработать", text: $scenario.title, axis: .vertical)
                .lineLimit(1...2)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .tint(Theme.accent)

            GlassNoteField(
                placeholder: "Заметки по сценарию…",
                text: $scenario.note,
                limit: 500,
                lines: 2...5,
                minHeight: 54
            )
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }
}
