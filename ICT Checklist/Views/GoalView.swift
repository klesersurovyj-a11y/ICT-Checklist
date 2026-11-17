//
//  GoalView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct GoalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: \Trade.entryDate) private var trades: [Trade]
    @Query private var goals: [MonthlyGoal]

    @State private var showEditor = false

    private var calendar: Calendar { Calendar.current }

    // MARK: - Data

    private var currentMonthStart: Date {
        monthStart(for: .now)
    }

    private func monthStart(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func goal(for start: Date) -> MonthlyGoal? {
        goals.first { calendar.isDate($0.monthStart, equalTo: start, toGranularity: .month) }
    }

    private func closedTrades(in start: Date) -> [Trade] {
        trades.filter {
            $0.result != .open
                && calendar.isDate($0.tradingDay, equalTo: start, toGranularity: .month)
        }
    }

    private var targetR: Double {
        goal(for: currentMonthStart)?.targetR ?? 10
    }

    private var monthR: Double {
        closedTrades(in: currentMonthStart).reduce(0) { $0 + $1.actualR }
    }

    private var fraction: Double {
        guard targetR > 0 else { return 0 }
        return min(max(monthR / targetR, 0), 1)
    }

    private var remaining: Double {
        max(targetR - monthR, 0)
    }

    private var tradingDaysLeft: Int {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonthStart),
              let end = calendar.date(byAdding: .day, value: range.count - 1, to: currentMonthStart) else {
            return 0
        }

        let today = calendar.startOfDay(for: .now)
        var date = max(today, currentMonthStart)
        var count = 0

        while date <= end {
            let weekday = calendar.component(.weekday, from: date)
            if weekday != 1 && weekday != 7 {
                count += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }

        return count
    }

    private var remainingLine: String {
        if remaining <= 0.05 {
            return "Цель выполнена · \(plainR(monthR)) из \(targetText(targetR))"
        }
        let perDay = remaining / Double(max(tradingDaysLeft, 1))
        return "Осталось \(plainR(remaining)) · по \(String(format: "%.1f", perDay))R на торговый день"
    }

    private struct MonthRow: Identifiable {
        let id: String
        let monthStart: Date
        let monthTitle: String
        let r: Double
        let target: Double?

        var reached: Bool {
            guard let target else { return false }
            return r >= target
        }
    }

    private var pastMonths: [MonthRow] {
        var starts: [Date] = []

        func add(_ date: Date) {
            let start = monthStart(for: date)
            let known = starts.contains { calendar.isDate($0, equalTo: start, toGranularity: .month) }
            if !known {
                starts.append(start)
            }
        }

        for trade in trades where trade.result != .open {
            add(trade.tradingDay)
        }
        for goal in goals {
            add(goal.monthStart)
        }

        let current = currentMonthStart
        return starts
            .filter { $0 < current }
            .sorted(by: >)
            .map { start in
                MonthRow(
                    id: String(start.timeIntervalSince1970),
                    monthStart: start,
                    monthTitle: Fmt.month(start),
                    r: closedTrades(in: start).reduce(0) { $0 + $1.actualR },
                    target: goal(for: start)?.targetR
                )
            }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    backButton
                        .reveal(.slideLeft)
                    header
                        .reveal(.drop)
                    ring
                        .reveal(.zoom, 1)

                    Text(remainingLine)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .reveal(.rise, 2)

                    Button {
                        showEditor = true
                        Haptics.tap()
                    } label: {
                        Text("Изменить цель")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Theme.accent)
                            )
                            .shadow(color: Theme.accent.opacity(0.35), radius: 14, x: 0, y: 8)
                    }
                    .buttonStyle(PressableButtonStyle())

                    pastMonthsCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showEditor) {
            GoalEditorSheet(
                monthTitle: Fmt.monthYear(currentMonthStart),
                initialValue: targetR
            ) { value in
                saveGoal(value)
            }
        }
        .task { ensureCurrentGoal() }
    }

    // MARK: - Header

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.white.opacity(0.07)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 2)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Цель")
            ScreenTitle(text: "Цель месяца")
            Text(Fmt.monthYear(currentMonthStart))
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Ring

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 18)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Theme.accent.opacity(0.55),
                            Theme.accent
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.accent.opacity(0.55), radius: 18)

            VStack(spacing: 6) {
                Text(plainR(monthR))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("из \(targetText(targetR))")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 40)
        }
        .frame(width: 250, height: 250)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    // MARK: - Past months

    private var pastMonthsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ПРОШЛЫЕ МЕСЯЦЫ")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 4)

            if pastMonths.isEmpty {
                Text("Пока нет прошлых месяцев")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(pastMonths.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Divider()
                            .overlay(Theme.hairline)
                    }
                    monthRow(row)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 24)
    }

    private func monthRow(_ row: MonthRow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.monthTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(rowSubtitle(row))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(row.reached ? Theme.green.opacity(0.18) : Color.white.opacity(0.07))
                    .frame(width: 36, height: 36)
                Image(systemName: row.reached ? "checkmark" : "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(row.reached ? Theme.green : Theme.textTertiary)
            }
        }
        .padding(.vertical, 12)
    }

    private func rowSubtitle(_ row: MonthRow) -> String {
        let r = Fmt.r(row.r)
        guard let target = row.target else {
            return "\(r) · цель —"
        }
        return "\(r) · цель \(targetText(target))"
    }

    // MARK: - Actions

    private func ensureCurrentGoal() {
        let current = currentMonthStart
        guard goal(for: current) == nil else { return }
        context.insert(MonthlyGoal(monthStart: current, targetR: 10))
        try? context.save()
    }

    private func saveGoal(_ value: Double) {
        let start = currentMonthStart
        let clamped = min(max(value.rounded(), 1), 1000)
        if let existing = goal(for: start) {
            existing.targetR = clamped
        } else {
            context.insert(MonthlyGoal(monthStart: start, targetR: clamped))
        }
        try? context.save()
        Haptics.success()
    }

    // MARK: - Formatting

    private func plainR(_ value: Double) -> String {
        let magnitude = abs(value)
        let text = magnitude >= 0.05 ? String(format: "%.1f", magnitude) : "0.0"
        let sign = value < -0.05 ? "\u{2212}" : ""
        return sign + text + "R"
    }

    private func targetText(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return "\(Int(rounded))R"
        }
        return plainR(value)
    }
}

// MARK: - Goal editor

private struct GoalEditorSheet: View {
    let monthTitle: String
    let initialValue: Double
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: Double = 10
    @State private var text: String = "10"

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Цель месяца")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Button("Готово") {
                    onSave(value)
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
            }

            Text(monthTitle)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 24) {
                stepButton(icon: "minus") {
                    value = max(value - 1, 1)
                    Haptics.select()
                }
                .disabled(value <= 1)

                HStack(spacing: 2) {
                    TextField("10", text: $text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.accent)
                        .frame(width: 96)
                    Text("R")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(minWidth: 130)

                stepButton(icon: "plus") {
                    value = min(value + 1, 1000)
                    Haptics.select()
                }
                .disabled(value >= 1000)
            }
            .frame(maxWidth: .infinity)
            .onChange(of: text) { _, newValue in
                guard let parsed = Int(newValue) else { return }
                value = Double(min(max(parsed, 1), 1000))
            }
            .onChange(of: value) { _, newValue in
                if Int(text) != Int(newValue) {
                    text = "\(Int(newValue))"
                }
            }

            Text("Шаг — 1R")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)

            Spacer(minLength: 0)
        }
        .padding(22)
        .presentationDetents([.height(290)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(32)
        .onAppear {
            value = max(initialValue.rounded(), 1)
            text = "\(Int(value))"
        }
    }

    private func stepButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}
