//
//  TodayView.swift
//  ICT Checklist
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \TradingCycle.createdAt, order: .reverse)
    private var cycles: [TradingCycle]

    @Query private var settingsList: [AppSettings]
    @Query private var ladderList: [RiskLadderState]
    @Query private var trades: [Trade]
    @Query private var plans: [TradePlan]

    @State private var continuedCycle: TradingCycle?
    @State private var isPaused = false
    @State private var didBootstrap = false
    @State private var navDirection: Int = 1
    @State private var showSettings = false
    @State private var showLevels = false
    @State private var showSecondBrain = false
    @State private var showWeekPlan = false
    @State private var showWeeklyPerformance = false
    @State private var showMore = false

    private var settings: AppSettings? { settingsList.first }
    private var ladder: RiskLadderState? { ladderList.first }
    private var minRR: Double { settings?.minRR ?? 2.0 }

    private var cycleStartText: String {
        Fmt.clock(hour: settings?.cycleStartHour ?? 19, minute: settings?.cycleStartMinute ?? 0)
    }

    private var cycleEndText: String {
        Fmt.clock(hour: settings?.cycleEndHour ?? 22, minute: settings?.cycleEndMinute ?? 0)
    }

    private var todayCycle: TradingCycle? {
        cycles.first { Calendar.current.isDateInToday($0.day) }
    }

    private var otherDraft: TradingCycle? {
        cycles.first { $0.result == .draft && !Calendar.current.isDateInToday($0.day) }
    }

    private var visibleCycle: TradingCycle? {
        continuedCycle ?? todayCycle
    }

    private var isStepFlowActive: Bool {
        guard let cycle = visibleCycle else { return false }
        return cycle.result == .draft && !isPaused
    }

    var body: some View {
        ZStack {
            AppBackground()
            scrollBody
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .toolbar(isStepFlowActive ? .hidden : .visible, for: .tabBar)
        .sheet(isPresented: $showSettings) {
            SettingsView(onClose: { showSettings = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showLevels) {
            LevelsView()
        }
        .fullScreenCover(isPresented: $showSecondBrain) {
            SecondBrainView()
        }
        .fullScreenCover(isPresented: $showWeekPlan) {
            WeekPlanView()
        }
        .fullScreenCover(isPresented: $showWeeklyPerformance) {
            WeeklyPerformanceView()
        }
        .fullScreenCover(isPresented: $showMore) {
            MoreView(isModal: true)
        }
        .task { bootstrap() }
        .onChange(of: visibleCycle?.resultRaw) { _, _ in
            CycleActivityController.shared.sync(context: context)
        }
    }

    // MARK: - Scroll content

    private var scrollBody: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Color.clear
                        .frame(height: 1)
                        .id("top")
                    header
                        .reveal(.drop)
                    if visibleCycle == nil || isPaused {
                        overviewCard
                            .reveal(.zoom, 1)
                    }
                    if let cycle = todayCycle, cycle.stopDay {
                        stopDayBanner(cycle)
                            .reveal(.blur, 2)
                    } else if dailyLimitReached {
                        dailyLimitBanner
                            .reveal(.blur, 2)
                    }
                    if !weekClosedTrades.isEmpty {
                        weekSummaryCard
                            .reveal(.rise, 2)
                    }
                    content
                        .reveal(.rise, 3)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: visibleCycle?.stepRaw) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Сегодня")
                ScreenTitle(text: "Цикл \(cycleStartText) → \(cycleEndText)")
                Text(headerSubtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                dailyLimitBadge
            }
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                Button {
                    showMore = true
                    Haptics.tap()
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .glassCircle()
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    showWeekPlan = true
                    Haptics.tap()
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .glassCircle()
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    showSecondBrain = true
                    Haptics.tap()
                } label: {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .glassCircle()
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    showLevels = true
                    Haptics.tap()
                } label: {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .glassCircle()
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    showSettings = true
                    Haptics.tap()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .glassCircle()
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerSubtitle: String {
        if let cycle = visibleCycle {
            let date = Fmt.day(cycle.day)
            switch cycle.result {
            case .draft:
                return "\(date) · черновик сохранён"
            case .entry:
                if let result = cycle.trade?.result, result != .open {
                    return "\(date) · сделка закрыта"
                }
                return "\(date) · сделка открыта"
            case .stopped:
                return "\(date) · STOP DAY"
            }
        }
        if let draft = otherDraft {
            return "\(Fmt.day(draft.day)) · незавершённый цикл"
        }
        return "\(Fmt.day(.now)) · новый цикл"
    }

    // MARK: - Week summary

    private var weekCalendar: Calendar { Calendar.current }

    private var weekStartDate: Date {
        let today = weekCalendar.startOfDay(for: .now)
        return weekCalendar.date(byAdding: .day, value: -6, to: today) ?? today
    }

    private var weekClosedTrades: [Trade] {
        let calendar = weekCalendar
        let from = weekStartDate

        return trades.filter { trade in
            guard trade.result != .open else { return false }
            return calendar.startOfDay(for: trade.tradingDay) >= from
        }
    }

    private var weekTotalR: Double {
        weekClosedTrades.reduce(0) { $0 + $1.actualR }
    }

    private var weekWinRate: Int {
        guard !weekClosedTrades.isEmpty else { return 0 }
        let wins = weekClosedTrades.filter { $0.actualR > 0.05 }.count
        return Int((Double(wins) / Double(weekClosedTrades.count) * 100).rounded())
    }

    private var weekBestDay: (date: Date, r: Double)? {
        var totals: [Date: Double] = [:]

        for trade in weekClosedTrades {
            let day = weekCalendar.startOfDay(for: trade.tradingDay)
            totals[day, default: 0] += trade.actualR
        }

        return totals.max { $0.value < $1.value }.map { ($0.key, $0.value) }
    }

    private var weekTotalTint: Color {
        if weekTotalR > 0.05 { return Theme.green }
        if weekTotalR < -0.05 { return Theme.red }
        return Theme.textPrimary
    }

    private var weekSummaryCard: some View {
        Button {
            showWeeklyPerformance = true
            Haptics.tap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    SectionLabel(text: "Итоги недели")
                    Spacer(minLength: 8)
                    Text("7 дней")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.textTertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(Fmt.r(weekTotalR))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(weekTotalTint)
                        .contentTransition(.numericText())

                    Text("\(Fmt.deals(weekClosedTrades.count)) · \(weekWinRate)% win rate")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                if let best = weekBestDay {
                    Text("Лучший день · \(Fmt.weekday(best.date)) · \(Fmt.r(best.r))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .glassCard(cornerRadius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Overview

    private var overviewStep: Int {
        min(max(ladder?.stepIndex ?? 0, 0), 2)
    }

    private var overviewAmount: Double {
        settings?.ladderAmount(at: overviewStep) ?? 12
    }

    private var overviewNextAmount: Double? {
        overviewStep < 2 ? settings?.ladderAmount(at: overviewStep + 1) : nil
    }

    private var overviewAccumulated: Double {
        ladder?.accumulatedR ?? 0
    }

    private var overviewTint: Color {
        overviewAccumulated >= 0 ? Theme.green : Theme.red
    }

    private var cumulativeRSeries: [Double] {
        let closed = trades
            .filter { $0.result != .open }
            .sorted { ($0.closedAt ?? $0.entryDate) < ($1.closedAt ?? $1.entryDate) }
        guard !closed.isEmpty else { return [0, 0] }

        var running = 0.0
        var values = [0.0]
        for trade in closed {
            running += trade.actualR
            values.append(running)
        }
        return Array(values.suffix(16))
    }

    private var todayClosedR: Double {
        trades
            .filter { $0.closedAt.map { Calendar.current.isDateInToday($0) } ?? false }
            .reduce(0) { $0 + $1.actualR }
    }

    // MARK: - Daily limits

    private var limitsEnabled: Bool { settings?.dailyLimitsEnabled ?? false }

    private var maxDailyLossR: Double { max(settings?.maxDailyLossR ?? 2, 0.5) }

    private var maxTradesPerDay: Int { max(settings?.maxTradesPerDay ?? 2, 1) }

    private var todayTrades: [Trade] {
        trades.filter { Calendar.current.isDateInToday($0.tradingDay) }
    }

    private var todayLimitR: Double {
        todayTrades
            .filter { $0.result != .open }
            .reduce(0) { $0 + $1.actualR }
    }

    private var dailyLimitReached: Bool {
        guard limitsEnabled else { return false }
        if todayTrades.count >= maxTradesPerDay { return true }
        return todayLimitR <= -maxDailyLossR + 0.0001
    }

    private var dailyLimitTint: Color {
        if dailyLimitReached { return Theme.red }
        let tradesLeft = maxTradesPerDay - todayTrades.count
        let rLeft = maxDailyLossR + todayLimitR
        if tradesLeft <= 1 || rLeft <= 1 { return Theme.orange }
        return Theme.green
    }

    private var dailyLimitText: String {
        "Сделок \(todayTrades.count)/\(maxTradesPerDay) · \(Fmt.r(todayLimitR)) / \(Fmt.r(-maxDailyLossR))"
    }

    @ViewBuilder
    private var dailyLimitBadge: some View {
        if limitsEnabled {
            Text(dailyLimitText)
                .font(.system(size: 11.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(dailyLimitTint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(dailyLimitTint.opacity(0.14)))
                .overlay(Capsule().strokeBorder(dailyLimitTint.opacity(0.4), lineWidth: 1))
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var dailyLimitBanner: some View {
        if dailyLimitReached {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("ЛИМИТ ДНЯ")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.orange)
                    Text("Лимит дня · новых входов нет. Следующий цикл в \(cycleStartText).")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.orange.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.orange.opacity(0.35), lineWidth: 1)
            )
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: "stairs")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(text: "Risk ladder")
                    Text("Ступень \(overviewStep + 1) из 3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer(minLength: 4)
                Text("\(overviewStep + 1)/3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.accent.opacity(0.14)))
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(text: "Риск на сделку")
                    Text(Fmt.money(overviewAmount))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    Image(systemName: overviewAccumulated >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(Fmt.r(overviewAccumulated))
                        .font(.system(size: 11.5, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(overviewTint)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(overviewTint.opacity(0.14)))
            }

            RSparkline(values: cumulativeRSeries, tint: overviewTint)
                .frame(height: 60)

            HStack {
                Text(overviewNextAmount.map { "до \(Fmt.money($0))" } ?? "потолок")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("сегодня \(Fmt.r(todayClosedR))")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func stopDayBanner(_ cycle: TradingCycle) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.red)
            VStack(alignment: .leading, spacing: 3) {
                Text("STOP DAY")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.red)
                Text("SL в этом дне — новых входов нет. Следующий цикл в \(cycleStartText).")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.red.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.red.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Main content

    @ViewBuilder
    private var content: some View {
        if let cycle = visibleCycle {
            if cycle.result == .draft {
                if isPaused {
                    pausedCard(cycle)
                } else {
                    cycleFlow(cycle)
                }
            } else if Calendar.current.isDateInToday(cycle.day) {
                DayResultView(cycle: cycle, onDone: nil)
            } else {
                DayResultView(cycle: cycle) {
                    withAnimation(.easeInOut) {
                        continuedCycle = nil
                    }
                }
            }
        } else {
            if let draft = otherDraft {
                draftBanner(draft)
            }
            startCard
        }
    }

    @ViewBuilder
    private func cycleFlow(_ cycle: TradingCycle) -> some View {
        progressCard(cycle)
        StepCardView(cycle: cycle, step: cycle.step, ladder: ladder, settings: settings)
            .id(cycle.stepRaw)
            .transition(stepTransition)
        completedSection(cycle)
        RouteMapView(currentIndex: cycle.step.routeIndex)
    }

    private var stepTransition: AnyTransition {
        if navDirection >= 0 {
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        }
        return .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }

    private func progressCard(_ cycle: TradingCycle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                Text("ШАГ \(cycle.step.number) ИЗ \(CycleStep.total)")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 4)
                ladderBadge(cycle)
            }
            StepRailView(currentGroup: cycle.step.group)
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private func ladderBadge(_ cycle: TradingCycle) -> some View {
        Text("Ступень \(cycle.ladderStepIndex + 1) · \(Fmt.money(cycle.riskUSD)) · \(Fmt.r(cycle.accumulatedR))")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.orange)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Theme.orange.opacity(0.14)))
            .overlay(Capsule().strokeBorder(Theme.orange.opacity(0.45), lineWidth: 1))
    }

    @ViewBuilder
    private func completedSection(_ cycle: TradingCycle) -> some View {
        let done = CycleStep.allCases.filter { $0.rawValue < cycle.stepRaw }
        if !done.isEmpty {
            VStack(spacing: 10) {
                if done.count > 3 {
                    Text("Ещё \(done.count - 3) шагов пройдено")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(done.suffix(3))) { step in
                    CompletedStepRow(step: step, summary: stepSummary(step, cycle)) {
                        jump(to: step, in: cycle)
                    }
                }
            }
        }
    }

    private func pausedCard(_ cycle: TradingCycle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ЧЕРНОВИК")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.orange)
            Text("Цикл на паузе")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Шаг \(cycle.step.number) из \(CycleStep.total) · \(cycle.step.title)")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
            Text("Один цикл — один торговый день. Всё, что уже заполнено, сохранено.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textTertiary)
            PrimaryButton(title: "Продолжить цикл", icon: "arrow.right") {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    isPaused = false
                }
                Haptics.tap()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 22)
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ЦИКЛ ДНЯ")
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.accent)
            Text("Новый торговый день")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("\(cycleStartText) — запуск цикла, \(cycleEndText) — закрытие терминала. Между ними рынок анализируется и принимается решение.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(title: "Начать цикл", icon: "arrow.right") {
                startCycle()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 22)
    }

    private func draftBanner(_ draft: TradingCycle) -> some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                continuedCycle = draft
                isPaused = false
            }
            Haptics.tap()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Незавершённый цикл")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(Fmt.day(draft.day)) · шаг \(draft.step.number) из \(CycleStep.total)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 4)
                Text("Продолжить")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
            .glassCard(cornerRadius: 22)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if let cycle = visibleCycle, cycle.result == .draft, !isPaused {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Button {
                        goBack(cycle)
                    } label: {
                        Text("Назад")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(cycle.stepRaw == 0)
                    .opacity(cycle.stepRaw == 0 ? 0.4 : 1)

                    Button {
                        goNext(cycle)
                    } label: {
                        HStack(spacing: 8) {
                            Text(primaryLabel(cycle))
                            Image(systemName: cycle.step == .entry ? "checkmark" : "arrow.right")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(canAdvance(cycle) ? Theme.accent : Theme.accent.opacity(0.3))
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(!canAdvance(cycle))
                }

                if let hint = blockingHint(cycle) {
                    Text(hint)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.orange)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isPaused = true
                    }
                    save()
                    Haptics.tap()
                } label: {
                    Text("Завершить позже")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 4)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 0.5)
                    }
            }
        }
    }

    private func primaryLabel(_ cycle: TradingCycle) -> String {
        cycle.step == .entry ? "Открыть сделку" : "Далее"
    }

    // MARK: - Validation

    private func canAdvance(_ cycle: TradingCycle) -> Bool {
        if cycle.step == .entry {
            guard !dailyLimitReached else { return false }
            guard let rr = cycle.computedRR else { return false }
            return rr >= minRR && cycle.pointAValid && cycle.pointBValid
        }
        return blockingHint(cycle) == nil
    }

    private func blockingHint(_ cycle: TradingCycle) -> String? {
        switch cycle.step {
        case .lastDR:
            if cycle.drHigh == nil || cycle.drLow == nil {
                return "Заполните верхнюю и нижнюю границы DR"
            }
            if (cycle.drHigh ?? 0) <= (cycle.drLow ?? 0) {
                return "Верхняя граница должна быть выше нижней"
            }
            return nil
        case .keyLevels:
            return cycle.activeKeyLevels.isEmpty ? "Добавьте хотя бы один актуальный Key Level" : nil
        case .keyLevelToPointA:
            return cycle.aConditionsMet ? nil : "Point A не сформирован — нужны все три условия"
        case .pointA:
            guard (cycle.pointAPrice ?? 0) > 0 else { return "Укажите цену Point A" }
            return cycle.pointAValid ? nil : "A не валиден — сформируйте новый Point A"
        case .pointB:
            guard (cycle.pointBPrice ?? 0) > 0 else { return "Укажите цену Point B" }
            return cycle.pointBValid ? nil : "B не валиден — сценарий завершён, нужен новый Point A"
        case .testA, .reaction, .slowdown, .fractals, .snr, .test:
            if cycle.scenarioEnded {
                return "Сценарий завершён — вернитесь к Point A"
            }
            guard let key = cycle.step.confirmationKey else { return nil }
            return cycle.confirmations.contains(key) ? nil : "Отметьте пункт, чтобы продолжить"
        case .rr:
            if cycle.scenarioEnded {
                return "Сценарий завершён — вход невозможен"
            }
            guard (cycle.entryPrice ?? 0) > 0,
                  (cycle.stopPrice ?? 0) > 0,
                  (cycle.takeProfit ?? 0) > 0 else {
                return "Заполните entry, SL и TP"
            }
            guard let rr = cycle.computedRR else {
                return "RR не посчитан — проверьте цены"
            }
            return rr >= minRR ? nil : "RR \(Fmt.rr(rr)) ниже минимума \(Fmt.rr(minRR)) — входа нет"
        case .entry:
            if dailyLimitReached {
                return "Лимит дня · новых входов нет до следующего цикла в \(cycleStartText)"
            }
            return nil
        default:
            return nil
        }
    }

    // MARK: - Actions

    private func goNext(_ cycle: TradingCycle) {
        if cycle.step == .entry {
            openTrade(cycle)
            return
        }
        if cycle.step == .pointA {
            syncScenarioOnLeavingA(cycle)
        } else if cycle.step == .pointB {
            syncScenarioOnLeavingB(cycle)
        }
        navDirection = 1
        let nextIndex = min(cycle.stepRaw + 1, CycleStep.entry.rawValue)
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            cycle.stepRaw = nextIndex
            cycle.updatedAt = .now
        }
        let newStep = CycleStep(rawValue: nextIndex) ?? .entry
        if newStep == .risk {
            syncRisk(cycle)
        }
        if newStep == .rr {
            prefillPrices(cycle)
        }
        Haptics.tap()
        save()
    }

    private func goBack(_ cycle: TradingCycle) {
        guard cycle.stepRaw > 0 else { return }
        navDirection = -1
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            cycle.stepRaw -= 1
            cycle.updatedAt = .now
        }
        Haptics.tap()
        save()
    }

    private func jump(to step: CycleStep, in cycle: TradingCycle) {
        navDirection = -1
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            cycle.stepRaw = step.rawValue
            cycle.updatedAt = .now
        }
        Haptics.tap()
        save()
    }

    private func syncRisk(_ cycle: TradingCycle) {
        let index = min(max(ladder?.stepIndex ?? 0, 0), 2)
        cycle.ladderStepIndex = index
        cycle.riskUSD = settings?.ladderAmount(at: index) ?? cycle.riskUSD
        cycle.accumulatedR = ladder?.accumulatedR ?? 0
    }

    private func prefillPrices(_ cycle: TradingCycle) {
        if cycle.stopPrice == nil, let a = cycle.pointAPrice {
            cycle.stopPrice = a
        }
        if cycle.takeProfit == nil, let b = cycle.pointBPrice {
            cycle.takeProfit = b
        }
    }

    private func startCycle() {
        guard !(todayCycle?.stopDay ?? false) else {
            Haptics.warning()
            return
        }
        let index = min(max(ladder?.stepIndex ?? 0, 0), 2)
        let amount = settings?.ladderAmount(at: index) ?? 12
        let symbol = settings?.symbols.first ?? "EURUSD"
        let cycle = TradingCycle(
            day: Calendar.current.startOfDay(for: .now),
            ladderStepIndex: index,
            riskUSD: amount,
            accumulatedR: ladder?.accumulatedR ?? 0,
            symbol: symbol
        )
        context.insert(cycle)
        save()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            continuedCycle = nil
            isPaused = false
        }
        Haptics.success()
    }

    // MARK: - Scenario records

    private func syncScenarioOnLeavingA(_ cycle: TradingCycle) {
        guard let price = cycle.pointAPrice, price > 0 else { return }

        let current = cycle.scenarios.first(where: { $0.isCurrent })
        let isNewA = current.map { abs($0.pointAPrice - price) > 1e-9 } ?? false

        if isNewA {
            cycle.pointBPrice = nil
            cycle.pointBType = .fractal
            cycle.pointBNote = ""
            cycle.pointBValid = true
            cycle.confirmations = []
            cycle.entryPrice = nil
            cycle.stopPrice = nil
            cycle.takeProfit = nil
        }

        let record: ScenarioRecord
        if let existing = cycle.scenarios.first(where: { abs($0.pointAPrice - price) < 1e-9 }) {
            record = existing
        } else {
            let created = ScenarioRecord(
                pointAPrice: price,
                pointADepth: cycle.pointADepth ?? 0,
                pointAValid: cycle.pointAValid
            )
            context.insert(created)
            cycle.scenarios.append(created)
            record = created
        }

        record.pointADepth = cycle.pointADepth ?? 0
        record.pointAValid = cycle.pointAValid

        for item in cycle.scenarios {
            item.isCurrent = false
        }
        record.isCurrent = true
        save()
    }

    private func syncScenarioOnLeavingB(_ cycle: TradingCycle) {
        guard let record = cycle.scenarios.first(where: { $0.isCurrent }) else { return }
        record.pointBPrice = cycle.pointBPrice
        record.pointBType = cycle.pointBType
        record.pointBValid = cycle.pointBValid
        record.pointAValid = cycle.pointAValid
        save()
    }

    private func openTrade(_ cycle: TradingCycle) {
        guard !cycle.stopDay, !dailyLimitReached else {
            Haptics.warning()
            return
        }
        guard let entry = cycle.entryPrice,
              let stop = cycle.stopPrice,
              let takeProfit = cycle.takeProfit,
              let rr = cycle.computedRR,
              rr >= minRR else {
            Haptics.warning()
            return
        }
        let trade = Trade(
            entryDate: .now,
            tradingDay: cycle.day,
            symbol: cycle.symbol,
            direction: cycle.direction,
            ladderStepIndex: cycle.ladderStepIndex,
            riskUSD: cycle.riskUSD,
            entry: entry,
            stop: stop,
            takeProfit: takeProfit,
            plannedRR: rr,
            note: cycle.pointANote
        )
        let plan = plans.first {
            Calendar.current.isDate($0.day, inSameDayAs: cycle.day)
        }
        context.insert(trade)
        trade.cycle = cycle
        trade.plan = plan
        cycle.trade = trade
        cycle.result = .entry
        cycle.updatedAt = .now
        save()
        Haptics.success()
    }

    private func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
        if settingsList.isEmpty {
            context.insert(AppSettings())
        }
        if ladderList.isEmpty {
            context.insert(RiskLadderState())
        }
        save()
        LadderEngine.sync(context: context)
    }

    private func save() {
        try? context.save()
    }

    // MARK: - Summaries

    private func stepSummary(_ step: CycleStep, _ cycle: TradingCycle) -> String {
        switch step {
        case .news:
            let count = [cycle.newsEUR, cycle.newsGBP, cycle.newsUSD].filter { $0 }.count
            if count == 0 { return "Новостей нет" }
            return count == 1 ? "1 важное событие" : "\(count) важных событий"
        case .risk:
            return "Ступень \(cycle.ladderStepIndex + 1), \(Fmt.money(cycle.riskUSD))"
        case .ofsof:
            return cycle.trendType.rawValue
        case .trendW1:
            return cycle.direction.rawValue
        case .lastDR:
            return "\(Fmt.price(cycle.drLow)) – \(Fmt.price(cycle.drHigh))"
        case .premiumDiscount:
            guard let zone = cycle.zone else { return "Зона не определена" }
            return cycle.zoneMismatch ? "\(zone.rawValue) · не соответствует" : zone.rawValue
        case .keyLevels:
            let count = cycle.activeKeyLevels.count
            return count == 1 ? "1 активный уровень" : "\(count) активных уровней"
        case .keyLevelToPointA:
            return cycle.aConditionsMet ? "A сформирован" : "A пока нет"
        case .pointA:
            guard let price = cycle.pointAPrice else { return "—" }
            return "\(Fmt.price(price)) · \(cycle.pointAValid ? "валиден" : "не валиден")"
        case .pointB:
            guard let price = cycle.pointBPrice else { return "—" }
            return "\(cycle.pointBType.rawValue) · \(Fmt.price(price))"
        case .testA, .reaction, .slowdown, .fractals, .snr, .test:
            guard let key = step.confirmationKey else { return "—" }
            return cycle.confirmations.contains(key) ? "Подтверждено" : "Не отмечено"
        case .symbol:
            return cycle.symbol
        case .rr:
            guard let rr = cycle.computedRR else { return "RR не посчитан" }
            return "RR \(Fmt.rr(rr))"
        case .entry:
            return "Вход открыт"
        }
    }
}
